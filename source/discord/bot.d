/**
* The main class for interacting with the discor.d library
* See_Also:
*	All functions in the following references can only be called from a `DiscordBot` instance:
*
*	`discord.rest.channel.RestChannel` for all REST methods relating to channels
*
*	`discord.rest.emoji.RestEmoji` for all REST methods relating to emojis
*
*	`discord.rest.guild.RestGuild` for all REST methods relating to guilds
*
*	`discord.rest.user.RestUser` for all REST methods relating to users
* Authors:
*	Emily Rose Ploszaj
*/
module discord.bot;

static import discord.events;
static import discord.types;

import core.time;
import core.thread;
import discord.events;
import discord.rest.channel;
import discord.rest.emoji;
import discord.rest.guild;
import discord.rest.user;
import discord.types;
import std.algorithm;
import std.conv;
import std.datetime.stopwatch;
import std.datetime.systime;
import std.datetime.timezone;
import std.experimental.logger;
import std.range;
import std.stdio;
import std.typecons;
import std.uri;
import vibe.data.json;
import vibe.http.client;
import vibe.http.websockets;

enum RouteType{
	Global, Guild, Channel, Webhook
}
/**
* Bot instance for interfacing with Discord's websocket and HTTP APIs
* See_Also:
*	All functions in the following references can only be called from a `DiscordBot` instance:
*
*	`discord.rest.channel.RestChannel` for all REST methods relating to channels
*
*	`discord.rest.emoji.RestEmoji` for all REST methods relating to emojis
*
*	`discord.rest.guild.RestGuild` for all REST methods relating to guilds
*
*	`discord.rest.user.RestUser` for all REST methods relating to users
*/
class DiscordBot{
	private enum DisconnectResult{
		None, Resume, Close
	}
	private struct RateLimitPath{
		RouteType type;
		long snowflake;
		this(RouteType type, long snowflake){
			this.type = type;
			this.snowflake = snowflake;
		}
	}
	private struct RateLimitInformation{
		int limit;
		int remaining;
		long reset;//Not really sure if this needs to be a long, better safe than sorry
		this(int limit, int remaining, long reset){
			this.limit = limit;
			this.remaining = remaining;
			this.reset = reset;
		}
	}
	private string gateway;
	private string sessionId;
	private string token;
	private int lastAck;
	private int heartbeatInterval = 10000;//10 seconds before things start going down
	private int seq;
	private RateLimitInformation[RateLimitPath] rateLimits;
	private Channel[ulong] channels;
	private Guild[ulong] guilds;
	private DiscordEvents events;
	private Logger logger;
	private User botUser;
	/**
	* Creates a Discord bot instance and prepares it to begin accepting events
	* Params:
	*	token =		The token of your Discord bot application
	*	events =	The event handler for your discord bot, should be a custom class that overwrites `discord.bot.DiscordEvents`
	*	logLevel =	The level of log detail you want to recieve, by default only critical or fatal events will be logged
	*/
	this(string token, DiscordEvents events, LogLevel logLevel = LogLevel.critical){
		this.token = token;
		this.events = events;
		logger = new FileLogger(stdout, logLevel);
	}
	/**
	* Starts the bot and begins the event loop, this method is blocking
	*/
	public void start(){
		HTTPClientResponse res = requestHTTP("https://discordapp.com/api/gateway/bot", (scope HTTPClientRequest req){
			req.headers.addField("Authorization", "Bot " ~ token);
		});
		if(res.statusCode != 200){
			logger.fatal("[discor.d] Gateway responded with error code: ", res.statusCode, ", ", res.statusPhrase, "\n[discor.d] Shutting down...");
			return;
		}
		gateway = res.readJson()["url"].get!string;
		DisconnectResult dcResult = DisconnectResult.None;
		while(true){
			connectWebSocket(URL(gateway ~ "/?v=6&encoding=json"), (scope WebSocket ws){
				dcResult = runLoop(ws, dcResult);
			});
			if(dcResult == DisconnectResult.Resume){
				logger.warning("[discor.d] Heartbeat ACK missed, resuming connection momentarily...");
				Thread.sleep(dur!"msecs"(6000));
			}else if(dcResult == DisconnectResult.Close){
				logger.fatal("[discor.d] Connection closed, shutting down...");
				break;
			}
		}
	}
	public DisconnectResult runLoop(WebSocket ws, DisconnectResult dcResult){
		scope(exit) ws.close();
		lastAck = 0;
		Json loginInfo = Json([
			"op": Json(2),
			"d": Json([
				"token": Json(token), 
				"properties": Json([
					"$os": Json(getSystemString()), 
					"$browser": Json("discor.d"),
					"$device": Json("discor.d")
				]),
				"compress": Json(false),
				"large_threshold": Json(250),
				"shard": Json([Json(0), Json(1)])
			])
		]);
		StopWatch sw;
		while(ws.connected){
			if(sw.peek >= msecs(heartbeatInterval)){
				if(seq == 0) ws.send(Json(["op": Json(1), "d": Json(null)]).toString());
				else ws.send(Json(["op": Json(1), "d": Json(seq)]).toString());
				lastAck++;
				sw.reset();
				if(lastAck > 1) return DisconnectResult.Resume;
			}
			if(ws.waitForData(dur!"msecs"(5000))){
				string text = ws.receiveText();//This is needed so text can be passed as a reference
				Json data = parseJson(text);
				int op = data["op"].get!int;
				logger.info("[discor.d] Recieved opcode: ", op);
				if(data["s"].type == Json.Type.int_) seq = data["s"].get!int;
				if(op == 0){//Dispatch (an event)
					logger.info("[discor.d] Event dispatched from gateway: ", data["t"].get!string);
					try{
						if(data["t"].get!string == "READY"){
							botUser = User(data["d"]["user"]);
							//Turns out private_channels doesn't do or contain anything?
							sessionId = data["d"]["session_id"].get!string;
							//TODO probably handle data["d"]["guilds"]
						}else if(data["t"].get!string == "CHANNEL_CREATE"){
							Channel channel = Channel(data["d"]);
							channels[channel.id] = channel;
							if(channel.guildId != 0) guilds[channel.guildId].channels ~= channel;
							events.channelCreate(channel);
						}else if(data["t"].get!string == "CHANNEL_UPDATE"){
							Channel channel = Channel(data["d"]);
							channels[channel.id] = channel;
							if(channel.guildId != 0){
								long i = guilds[channel.guildId].channels.countUntil!(c => c.id == channel.id);
								guilds[channel.guildId].channels[i] = channel;
							}
							events.channelUpdate(channel);
						}else if(data["t"].get!string == "CHANNEL_DELETE"){
							long id = data["t"]["id"].get!string.to!ulong;
							Channel channel = channels[id];
							channels.remove(id);
							if(channel.guildId != 0){
								long i = guilds[channel.guildId].channels.countUntil!(c => c.id == channel.id);
								guilds[channel.guildId].channels = guilds[channel.guildId].channels[0..i] ~ guilds[channel.guildId].channels[i + 1..$];
							}
							events.channelDelete(channel);
						}else if(data["t"].get!string == "CHANNEL_PINS_UPDATE"){
							long id = data["d"]["channel_id"].get!string.to!ulong;
							events.pinsUpdate(channels[id]);
						}else if(data["t"].get!string == "GUILD_CREATE"){
							Guild guild = Guild(data["d"]);
							guilds[guild.id] = guild;
							guild.channels.each!(c => channels[c.id] = c);
							events.guildCreate(guild);
						}else if(data["t"].get!string == "GUILD_UPDATE"){
							ulong id = data["d"]["id"].get!string.to!ulong;
							guilds[id].updateInfo(data["d"]);
							events.guildUpdate(guilds[id]);
						}else if(data["t"].get!string == "GUILD_DELETE"){
							ulong id = data["d"]["id"].get!string.to!ulong;
							Guild guild = guilds[id];
							guilds.remove(id);//TODO maybe hold a list of unavailable guilds for a different handling
							events.guildDelete(guild, data["d"]["unavailable"].type == Json.Type.undefined);
						}else if(data["t"].get!string == "GUILD_BAN_ADD"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Guild guild = guilds[id];
							events.guildBanAdd(guild, User(data["d"]["user"]));
						}else if(data["t"].get!string == "GUILD_BAN_REMOVE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Guild guild = guilds[id];
							events.guildBanRemove(guild, User(data["d"]["user"]));
						}else if(data["t"].get!string == "GUILD_EMOJIS_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							guilds[id].emojis = data["d"]["emojis"][].map!(e => Emoji(e)).array;
							events.guildEmojisUpdate(guilds[id]);
						}else if(data["t"].get!string == "GUILD_INTEGRATIONS_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							events.guildIntegrationsUpdate(guilds[id]);
						}else if(data["t"].get!string == "GUILD_MEMBER_ADD"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							GuildMember member = GuildMember(data["d"]);
							guilds[id].members ~= member;
							events.guildMemberAdd(guilds[id], member);
						}else if(data["t"].get!string == "GUILD_MEMBER_REMOVE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							User user = User(data["d"]["user"]);
							GuildMember member = guilds[id].members[guilds[id].members.countUntil!(m => m.user.id == user.id)()];
							guilds[id].members = guilds[id].members.remove!(m => m == member)();
							events.guildMemberRemove(guilds[id], member);
						}else if(data["t"].get!string == "GUILD_MEMBER_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							ulong userId = data["d"]["user"]["id"].get!string.to!ulong;
							long index = guilds[id].members.countUntil!(m => m.user.id == userId);
							guilds[id].members[index].nick = data["d"]["nick"].get!string;
							guilds[id].members[index].roleIds = data["d"]["roles"][].map!(r => r.get!string.to!ulong).array;
							guilds[id].members[index].user = User(data["d"]["user"]);
							events.guildMemberUpdate(guilds[id], guilds[id].members[index]);
						//NOTE GUILD_MEMBERS_CHUNK (Response to a request, not needed for now)
						}else if(data["t"].get!string == "GUILD_ROLE_CREATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Role role = Role(data["d"]["role"]);
							guilds[id].roles ~= role;
							events.guildRoleCreate(guilds[id], role);
						}else if(data["t"].get!string == "GUILD_ROLE_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Role role = Role(data["d"]["role"]);
							guilds[id].roles.find!(gr => gr.id == role.id)[0] = role;
							events.guildRoleUpdate(guilds[id], role);
						}else if(data["t"].get!string == "GUILD_ROLE_DELETE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							ulong roleId = data["d"]["role_id"].get!string.to!ulong;
							Role role = guilds[id].roles[guilds[id].roles.countUntil!(r => r.id == roleId)()];
							guilds[id].roles = guilds[id].roles.remove!(r => r == role)();
							events.guildRoleDelete(guilds[id], role);
						}else if(data["t"].get!string == "MESSAGE_CREATE"){
							Message message = Message(data["d"]);
							events.messageCreate(message);
						}else if(data["t"].get!string == "MESSAGE_UPDATE"){
							Message message = Message(data["d"]);
							events.messageUpdate(message);
						}else if(data["t"].get!string == "MESSAGE_DELETE"){
							ulong id = data["d"]["id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							events.messageDelete(channels[channelId], id);
						}else if(data["t"].get!string == "MESSAGE_DELETE_BULK"){
							ulong[] ids = data["d"]["ids"][].map!(m => m.get!string.to!ulong).array;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							events.messageDeleteBulk(channels[channelId], ids);
						}else if(data["t"].get!string == "MESSAGE_REACTION_ADD"){
							Emoji emoji = Emoji(data["d"]["emoji"]);
							ulong userId = data["d"]["user_id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							ulong messageId = data["d"]["message_id"].get!string.to!ulong;
							events.messageReactionAdd(channels[channelId], messageId, userId, emoji);
						}else if(data["t"].get!string == "MESSAGE_REACTION_REMOVE"){
							Emoji emoji = Emoji(data["d"]["emoji"]);
							ulong userId = data["d"]["user_id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							ulong messageId = data["d"]["message_id"].get!string.to!ulong;
							events.messageReactionRemove(channels[channelId], messageId, userId, emoji);
						}else if(data["t"].get!string == "MESSAGE_REACTION_REMOVE_ALL"){
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							ulong messageId = data["d"]["message_id"].get!string.to!ulong;
							events.messageReactionRemoveAll(channels[channelId], messageId);
						}else if(data["t"].get!string == "PRESENCE_UPDATE"){
							ulong guildId = data["d"]["guild_id"].get!string.to!ulong;
							ulong userId = data["d"]["user"]["id"].get!string.to!ulong;
							Role[] roles;
							if(data["d"]["roles"].type == Json.Type.array){
								data["d"]["roles"][].map!(r => guilds[guildId].roles.find!(gr => gr.id == r.get!string.to!ulong)[0]).array;
							}
							Game game;
							if(data["d"]["game"].type == Json.Type.object) game = Game(data["d"]["game"]);
							string status = data["d"]["status"].get!string;
							guilds[guildId].presences[userId] = game;
							events.presenceUpdate(guilds[guildId], userId, roles, game, status);
						}else if(data["t"].get!string == "TYPING_START"){
							ulong userId = data["d"]["user_id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							events.typingStart(channels[channelId], userId);
						}else if(data["t"].get!string == "USER_UPDATE"){
							User user = User(data["d"]);
							foreach(ref g; guilds.byValue()){
								long i = g.members.countUntil!(m => m.user.id == user.id);
								if(i != -1) g.members[i].user = user;
							}
						//NOTE VOICE_STATE_UPDATE all voice events unhandled
						//NOTE VOICE_SERVER_UPDATE all voice events unhandled
						//TODO WEBHOOKS_UPDATE
						}else logger.warning("[discor.d] Unhandled event recieved: ", data["t"].get!string, data["d"].get!string);
					}catch(Exception e){
						logger.warning("[discor.d] Unhandled exception in event dispatch:\n", e);
					}
				}else if(op == 1){//Requested heartbeat
					ws.send(Json(["op": Json(1), "d": Json(seq)]).toString());
					lastAck++;
				}else if(op == 10){//Hello
					if(dcResult == DisconnectResult.Resume){
						Json resume = Json([
							"token": Json(token),
							"session_id": Json(sessionId),
							"seq": Json(seq)
						]);
						ws.send(resume.toString());
					}else{
						heartbeatInterval = data["d"]["heartbeat_interval"].get!int;
						ws.send(loginInfo.toString());
						sw.start();
					}
				}else if(op == 11){//Heartbeat ACK
					lastAck--;
				}else logger.warning("[discor.d] Unhandled Gateway OP Code: ", op);
			}
		}
		return DisconnectResult.Close;
	}
	/**
	* Gets the current bot user's object
	*/
	public @property User getBotUser(){
		return botUser;
	}
	/**
	* Gets a list of all known channels
	*/
	public @property Channel[] getChannels(){
		return channels.values;
	}
	/**
	* Gets a list of all known guilds
	*/
	public @property Guild[] getGuilds(){
		return guilds.values;
	}
	///Gets a channel from the list of known channels
	public Channel getChannel(ulong id){
		if(id in channels) return channels[id];
		throw new Exception("Channel does not exist or may be unavailable (" ~ id.to!string ~ ")");
	}
	///Gets a guild from the list of known guilds
	public Guild getGuild(ulong id){
		if(id in guilds) return guilds[id];
		throw new Exception("Guild does not exist or may be unavailable (" ~ id.to!string ~ ")");
	}
	private bool requestResponse(string url, HTTPMethod method, Json message = Json.emptyObject, RouteType route = RouteType.Global, ulong snowflake = 0, scope void delegate(scope HTTPClientResponse) callback = cast(void delegate(scope HTTPClientResponse res)) null){
		RateLimitPath rlp = RateLimitPath(route, snowflake);
		//Manually keep track of rate limits
		if(rlp in rateLimits){
			RateLimitInformation rli = rateLimits[rlp];
			if(rli.reset < unixTime()){
				rateLimits.remove(rlp);
			}else if(rli.remaining <= 0){
				handleLimitedRequest(url, method, message, route, snowflake, callback);
				return false;
			}else{
				rateLimits[rlp].remaining--;//Preemptive modification, in case we don't get any
			}
		}
		HTTPClientResponse res = requestHTTP("https://discordapp.com/api/" ~ url, (scope HTTPClientRequest req){
			req.headers.addField("Authorization", "Bot " ~ token);
			req.headers.addField("Content-Type", "application/json");
			req.method = method;
			req.writeJsonBody(message);
		});
		//Rate limit information is not always passed, will always be passed if limits are exceeded though
		if("X-RateLimit-Limit" in res.headers && "X-RateLimit-Remaining" in res.headers && "X-RateLimit-Reset" in res.headers){
			rateLimits[rlp] = RateLimitInformation(
				res.headers["X-RateLimit-Limit"].to!int,
				res.headers["X-RateLimit-Remaining"].to!int,
				res.headers["X-RateLimit-Reset"].to!int
			);
		}
		if(res.statusCode == 429){
			handleLimitedRequest(url, method, message, route, snowflake, callback);
			return false;
		}
		if(res.statusCode != 200 && res.statusCode != 204){
			logger.warning("[discor.d] Error encountered when requesting response: ", res.statusCode, ", ", res.statusPhrase);
			return false;
		}
		if(callback !is null) callback(res);
		return true;
	}
	private void handleLimitedRequest(string url, HTTPMethod method, Json message = Json.emptyObject, RouteType route = RouteType.Global, ulong snowflake = 0, scope void delegate(scope HTTPClientResponse) callback = cast(void delegate(scope HTTPClientResponse res)) null){
		logger.warning("[discor.d] Event was rate limited: ", url);
		events.actionRateLimited(url, method, message);
	}
	//Handle all REST API functions relating to channels
	mixin RestChannel!(requestResponse);
	//Handle all REST API functions relating to emojis
	mixin RestEmoji!(requestResponse);
	//Handle all REST API functions relating to guilds
	mixin RestGuild!(requestResponse);
	//Handle all REST API functions relating to users
	mixin RestUser!(requestResponse);
}
//:)
private long unixTime(){
	return Clock.currTime(UTC()).toUnixTime();
}
private string getSystemString(){
	version(linux) return "linux";
	else version(OSX) return "macosx";
	else version(Windows) return "windows";
	else version(Posix) return "other/posix";
	else return "other/unknown";
}