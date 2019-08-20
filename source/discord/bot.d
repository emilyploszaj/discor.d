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

public import discord.cache;
public import discord.events;
public import discord.types;

import core.time;
import core.thread;
import discord.rest.channel;
import discord.rest.emoji;
import discord.rest.guild;
import discord.rest.user;
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
		None, Reconnect, Resume, Close
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
	private bool shutDown = false;
	private int lastAck;
	private int heartbeatInterval;
	private int seq;
	private RateLimitInformation[RateLimitPath] rateLimits;
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
	* Starts the bot and begins the event loop, this is a blocking method
	*/
	public void start(){
		shutDown = false;
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
			if(dcResult == DisconnectResult.Reconnect){
				logger.warning("[discor.d] Connection closed, reconnecting momentarily...");
				Thread.sleep(dur!"msecs"(6000));
			}else if(dcResult == DisconnectResult.Resume){
				logger.warning("[discor.d] Connection closed, resuming momentarily...");
				Thread.sleep(dur!"msecs"(6000));
			}else if(dcResult == DisconnectResult.Close){
				logger.fatal("[discor.d] Connection closed, shutting down...");
				break;
			}
		}
	}
	//TODO add ability to update user status (game status 5 times per minute limit)
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
				"large_threshold": Json(250)
			])
		]);
		StopWatch sw;//Please don't yell at me for having "sw" and "ws" as variable names
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
							addCachedUser(botUser);
							//Turns out private_channels doesn't do or contain anything?
							sessionId = data["d"]["session_id"].get!string;
							//TODO probably handle data["d"]["guilds"]
						}else if(data["t"].get!string == "CHANNEL_CREATE"){
							Channel channel = Channel(data["d"]);
							addCachedChannel(channel);
							if(channel.guildId != 0) modifyCachedGuild(channel.guildId, (ref Guild g){
								g.channelIds ~= channel.id;
							});
							events.channelCreate(channel);
						}else if(data["t"].get!string == "CHANNEL_UPDATE"){
							Channel channel = Channel(data["d"]);
							modifyCachedChannel(channel.id, (ref Channel c){
								c = channel;//As far as I can tell the entire channel is sent so reassignment is ideal
							});
							events.channelUpdate(channel);
						}else if(data["t"].get!string == "CHANNEL_DELETE"){
							ulong id = data["t"]["id"].get!string.to!ulong;
							Channel channel = getChannel(id);
							removeCachedChannel(id);
							if(channel.guildId != 0){
								modifyCachedGuild(channel.guildId, (ref Guild g){
									long i = g.channelIds.countUntil!(c => c == channel.id);
									g.channelIds = g.channelIds.remove(i);
								});
							}
							events.channelDelete(channel);
						}else if(data["t"].get!string == "CHANNEL_PINS_UPDATE"){//Info not sent with channels so caching is not important
							ulong id = data["d"]["channel_id"].get!string.to!ulong;
							events.pinsUpdate(getChannel(id));
						}else if(data["t"].get!string == "GUILD_CREATE"){
							Guild guild = Guild(data["d"]);
							foreach(Json j; data["d"]["channels"][]){
								Channel c = Channel(j);
								addCachedChannel(c);
								guild.channelIds ~= c.id;
							}
							addCachedGuild(guild);
							events.guildCreate(guild);
						}else if(data["t"].get!string == "GUILD_UPDATE"){
							ulong id = data["d"]["id"].get!string.to!ulong;
							modifyCachedGuild(id, (ref Guild g){
								g.updateInfo(data["d"]);
							});
							events.guildUpdate(getGuild(id));
						}else if(data["t"].get!string == "GUILD_DELETE"){
							ulong id = data["d"]["id"].get!string.to!ulong;
							Guild guild = getGuild(id);
							removeCachedGuild(id);//TODO maybe hold a list of unavailable guilds for a different handling
							events.guildDelete(guild, data["d"]["unavailable"].type == Json.Type.undefined);
						}else if(data["t"].get!string == "GUILD_BAN_ADD"){//Info not sent with guild so caching is not important
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Guild guild = getGuild(id);
							events.guildBanAdd(guild, User(data["d"]["user"]));//Sending partial info
						}else if(data["t"].get!string == "GUILD_BAN_REMOVE"){//Info not sent with guild so caching is not important
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Guild guild = getGuild(id);
							events.guildBanRemove(guild, User(data["d"]["user"]));//Sending partial info
						}else if(data["t"].get!string == "GUILD_EMOJIS_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							modifyCachedGuild(id, (ref Guild g){
								g.emojis = data["d"]["emojis"][].map!(e => Emoji(e)).array;
							});
							events.guildEmojisUpdate(getGuild(id));
						}else if(data["t"].get!string == "GUILD_INTEGRATIONS_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							events.guildIntegrationsUpdate(getGuild(id));
						}else if(data["t"].get!string == "GUILD_MEMBER_ADD"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							GuildMember member = GuildMember(data["d"]);
							modifyCachedGuild(id, (ref Guild g){
								g.members ~= member;
							});
							addCachedUser(User(data["d"]["user"]));
							events.guildMemberAdd(getGuild(id), member);
						}else if(data["t"].get!string == "GUILD_MEMBER_REMOVE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							User user = User(data["d"]["user"]);
							GuildMember member;
							modifyCachedGuild(id, (ref Guild g){
								long i = g.members.countUntil!(m => m.user.id == user.id);
								member = g.members[i];
								g.members = g.members.remove(i);
							});
							events.guildMemberRemove(getGuild(id), member);
						}else if(data["t"].get!string == "GUILD_MEMBER_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							ulong userId = data["d"]["user"]["id"].get!string.to!ulong;
							GuildMember member;
							modifyCachedGuild(id, (ref Guild g){
								long i = g.members.countUntil!(m => m.userId == userId);
								g.members[i].nick = data["d"]["nick"].get!string;
								g.members[i].roleIds = data["d"]["roles"][].map!(r => r.get!string.to!ulong).array;
								member = g.members[i];
							});
							addCachedUser(User(data["d"]["user"]));//Should be a full user object
							events.guildMemberUpdate(getGuild(id), member);
						//NOTE GUILD_MEMBERS_CHUNK (Response to a request, not needed for now)
						}else if(data["t"].get!string == "GUILD_ROLE_CREATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Role role = Role(data["d"]["role"]);
							modifyCachedGuild(id, (ref Guild g){
								g.roles ~= role;
							});
							events.guildRoleCreate(getGuild(id), role);
						}else if(data["t"].get!string == "GUILD_ROLE_UPDATE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							Role role = Role(data["d"]["role"]);
							modifyCachedGuild(id, (ref Guild g){
								long i = g.roles.countUntil!(r => r.id == role.id);
								g.roles[i] = role;
							});
							events.guildRoleUpdate(getGuild(id), role);
						}else if(data["t"].get!string == "GUILD_ROLE_DELETE"){
							ulong id = data["d"]["guild_id"].get!string.to!ulong;
							ulong roleId = data["d"]["role_id"].get!string.to!ulong;
							Role role;
							modifyCachedGuild(id, (ref Guild g){
								long i = g.roles.countUntil!(r => r.id == role.id);
								role = g.roles[i];
								g.roles = g.roles.remove(i);
							});
							events.guildRoleDelete(getGuild(id), role);
						}else if(data["t"].get!string == "MESSAGE_CREATE"){
							Message message = Message(data["d"]);
							modifyCachedChannel(message.channelId, (ref Channel c){
								c.lastMessageId = message.id;
							});
							events.messageCreate(message);
						}else if(data["t"].get!string == "MESSAGE_UPDATE"){
							Message message = Message(data["d"]);
							events.messageUpdate(message);
						}else if(data["t"].get!string == "MESSAGE_DELETE"){//Might result in removing the last message
							ulong id = data["d"]["id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							events.messageDelete(getChannel(channelId), id);
						}else if(data["t"].get!string == "MESSAGE_DELETE_BULK"){//Might result in removing the last message
							ulong[] ids = data["d"]["ids"][].map!(m => m.get!string.to!ulong).array;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							events.messageDeleteBulk(getChannel(channelId), ids);
						}else if(data["t"].get!string == "MESSAGE_REACTION_ADD"){//TODO use cache
							Emoji emoji = Emoji(data["d"]["emoji"]);
							ulong userId = data["d"]["user_id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							ulong messageId = data["d"]["message_id"].get!string.to!ulong;
							events.messageReactionAdd(getChannel(channelId), messageId, userId, emoji);
						}else if(data["t"].get!string == "MESSAGE_REACTION_REMOVE"){//TODO use cache
							Emoji emoji = Emoji(data["d"]["emoji"]);
							ulong userId = data["d"]["user_id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							ulong messageId = data["d"]["message_id"].get!string.to!ulong;
							events.messageReactionRemove(getChannel(channelId), messageId, userId, emoji);
						}else if(data["t"].get!string == "MESSAGE_REACTION_REMOVE_ALL"){
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							ulong messageId = data["d"]["message_id"].get!string.to!ulong;
							events.messageReactionRemoveAll(getChannel(channelId), messageId);
						}else if(data["t"].get!string == "PRESENCE_UPDATE"){
							ulong guildId = data["d"]["guild_id"].get!string.to!ulong;
							ulong userId = data["d"]["user"]["id"].get!string.to!ulong;
							Role[] roles;
							Activity activity;
							string status = data["d"]["status"].get!string;
							if(data["d"]["game"].type == Json.Type.object) activity = Activity(data["d"]["game"]);
							modifyCachedGuild(guildId, (ref Guild g){
								if(data["d"]["roles"].type == Json.Type.array){
									roles = data["d"]["roles"][].map!(r => g.roles.find!(gr => gr.id == r.get!string.to!ulong)[0]).array;
								}
								g.presences[userId] = activity;
							});
							events.presenceUpdate(getGuild(guildId), userId, roles, activity, status);
						}else if(data["t"].get!string == "TYPING_START"){
							ulong userId = data["d"]["user_id"].get!string.to!ulong;
							ulong channelId = data["d"]["channel_id"].get!string.to!ulong;
							events.typingStart(getChannel(channelId), userId);
						}else if(data["t"].get!string == "USER_UPDATE"){
							botUser = User(data["d"]);
						//NOTE VOICE_STATE_UPDATE all voice events unhandled
						//NOTE VOICE_SERVER_UPDATE all voice events unhandled
						//TODO WEBHOOKS_UPDATE
						}else logger.warning("[discor.d] Unhandled event recieved: ", data["t"].get!string, data["d"].get!string);
					}catch(Exception e){
						logger.critical("[discor.d] Unhandled exception in event dispatch:\n", e);
					}
					if(shutDown){
						return DisconnectResult.Close;
					}
				}else if(op == 1){//Requested heartbeat
					ws.send(Json(["op": Json(1), "d": Json(seq)]).toString());
					lastAck++;
				}else if(op == 7){//We've been asked nicely to reconnect
					logger.warning("[discor.d] OP 7: Reconnecting as requested");
					return DisconnectResult.Reconnect;
				}else if(op == 9){//We've been asked nicely to reconnect
					logger.warning("[discor.d] OP 9: Invalid session ID");
					return DisconnectResult.Reconnect;
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
				}else if(op == 4000){
					logger.critical("[discor.d] OP 4000: Unknown error");
					return DisconnectResult.Reconnect;
				}else if(op == 4001){
					logger.fatal("[discor.d] OP 4001: Invalid opcode was sent by client");
					return DisconnectResult.Close;
				}else if(op == 4002){
					logger.fatal("[discor.d] OP 4002: Invalid payload was sent by client");
					return DisconnectResult.Close;
				}else if(op == 4003){
					logger.fatal("[discor.d] OP 4003: A payload was sent before identifying");
					return DisconnectResult.Close;
				}else if(op == 4004){
					logger.fatal("[discor.d] OP 4004: Authentication token is invalid");
					return DisconnectResult.Close;
				}else if(op == 4005){
					logger.fatal("[discor.d] OP 4005: Multiple identify events were sent by client");
					return DisconnectResult.Close;
				}else if(op == 4007){
					logger.critical("[discor.d] OP 4007: Invalid seq passed on resume");
					return DisconnectResult.Reconnect;
				}else if(op == 4008){
					logger.fatal("[discor.d] OP 4008: Gateway rate limited");
					return DisconnectResult.Close;
				}else if(op == 4009){
					logger.critical("[discor.d] OP 4009: Session timed out");
					return DisconnectResult.Reconnect;
				}else if(op == 4010){
					logger.fatal("[discor.d] OP 4010: Invalid shard sent when identifying");
					return DisconnectResult.Close;
				}else if(op == 4011){
					logger.fatal("[discor.d] OP 4011: Client requires sharding");
					return DisconnectResult.Close;
				}else logger.warning("[discor.d] Unhandled Gateway OP Code: ", op);
			}
		}
		return DisconnectResult.Reconnect;
	}
	/**
	* Shuts down the bot gracefully 
	*/
	public void stop(){
		shutDown = true;
	}
	/**
	* Gets the current bot user's object
	*/
	public @property User getMe(){
		return botUser;
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
		scope(exit) res.dropBody();
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
		if(res.statusCode != 200 && res.statusCode != 201 && res.statusCode != 204){
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