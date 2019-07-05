/**
* A collection of types representing the Discord data types
* Authors:
*	Emily Rose Ploszaj
*/
module discord.types;

import discord.bot;
import discord.cache;
import std.algorithm;
import std.array;
import std.conv;
import std.typecons;
import vibe.data.json;

/**
* A channel (text, voice, category, etc.)
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void tellMeAboutAChannel(Channel channel){
*		if(channel.type == Channel.Type.GuildText){
*			//A text channel in a guild
*			writeln("This is a chat between a lot of people in a guild!");
*			
*			//Print out whether it's nsfw
*			if(channel.nsfw) writeln("This is an NSFW channel, stay out if you're not 18 yet!");
*			else writeln("This isn't an NSFW channel, feel free to check it out!");
*		}else if(channel.type == Channel.Type.DM){
*			//A DM between two people
*			writeln("This is a chat between two people!");
*
*			//Print the two users who are in the DM
*			writeln("User one is ", channel.recipients[0].name);
*			writeln("User two is ", channel.recipients[1].name);
*		}else{
*			//One of GuildVoice, GroupDM, GuildCategory, GuildNews, or GuildStore
*			writeln("Not a simple text channel!");
*		}
*	}
* ---
*/
struct Channel{
	///The different types of channels
	public enum Type{
		GuildText = 0, DM, GuildVoice, GroupDM, GuildCategory, GuildNews, GuildStore
	}
	///The name of the channel
	public Nullable!string name;
	///The topic text displayed under the name
	public Nullable!string topic;
	///The id of the `discord.types.Guild` this channel is in
	public Nullable!ulong guildId;
	///The id of the channel
	public ulong id;
	///The id of the last message sent in this channel
	public Nullable!ulong lastMessageId;
	///The id of this channel's parent
	public Nullable!ulong parentId;
	///Whether this channel is not safe for work
	public Nullable!bool nsfw;
	///The bitrate of this channel
	public Nullable!int bitrate;
	///The sidebar position of this channel
	public Nullable!int position;
	///The rate limit each user has in this channel
	public Nullable!int rateLimitPerUser;
	///The user limit in this channel
	public Nullable!int userLimit;
	///The list of users participating in a DM
	public Nullable!(User[]) recipients;
	///The type of channel
	public Type type;
	this(Json json){
		name.safeAssign(json, "name");
		topic.safeAssign(json, "topic");
		guildId.safeAssign(json, "guild_id");
		id = json["id"].get!string.to!ulong;
		lastMessageId.safeAssign(json, "last_message_id");
		parentId.safeAssign(json, "parent_id");
		nsfw.safeAssign(json, "nsfw");
		type = cast(Type) json["type"].get!int;
		bitrate.safeAssign(json, "bitrate");
		position.safeAssign(json, "position");
		rateLimitPerUser.safeAssign(json, "rate_limit_per_user");
		userLimit.safeAssign(json, "user_limit");
		if(json["recipients"].type == Json.Type.array) recipients = json["recipients"][].map!(u => User(u)).array;
	}
	///Whether this channel is in a `discord.types.Guild`
	public @property bool hasGuild(){
		return !guildId.isNull;
	}
	///The `discord.types.Guild` that this channel is in
	public @property Guild guild(){
		return getGuild(guildId);
	}
	///Wheter this channel has a parent channel
	public @property bool hasParent(){
		return !parentId.isNull;
	}
	///The parent channel of this channel
	public @property Channel parent(){
		return getChannel(parentId);
	}
}
/**
* A guild
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void tellMeAboutAGuild(Guild guild){
*		if(guild.large){
*			//A very large guild
*			writeln("This is a very big guild!");
*		}else{
*			//A smaller guild
*			writeln("This is a smaller guild!");
*		}
*			
*		//Print out the number of channels
*		writeln("This guild has ", guild.channels.length, " different channels!");
*	}
* ---
*/
struct Guild{//TODO there seems to be a lot of missing values in here
	///The default message notification level in a guild
	enum MessageNotificationLevel{
		AllMessages = 0, OnlyMentions
	}
	///Explicit content filtering level in a guild
	enum ExplicitContentFilterLevel{
		Disabled = 0, MembersWithoutRoles, AllMembers
	}
	///Multi-factor authentication levels needed in a guild
	enum MFALevel{
		None = 0, Elevated
	}
	///Verification levels needed to act in a guild
	enum VerificationLevel{
		None = 0,	///Unresricted
		Low,		///Must have verified email on account
		Medium,		///Must be registered on Discord for longer than 5 minutes
		High,		///Must be a member on the guild for longer than 10 minutes
		VeryHigh	///Must have a verified phone number
	}
	///The icon hash of the guild
	public Nullable!string icon;
	///The name of the guild
	public string name;
	///The region code the guild is in
	public string region;
	///The splash hash of the guild
	public Nullable!string splash;
	///The id of the afk channel
	public Nullable!ulong afkChannelId;
	///The id of the embed channel
	public Nullable!ulong embedChannelId;
	///The id of the guild
	public ulong id;
	///The id of the `discord.types.User` who owns the guild
	public ulong ownerId;
	///Whether the guild is embeddable
	public Nullable!bool embedEnabled;
	///Wheter this guild is considered "large"
	public Nullable!bool large;
	///The afk timeout in seconds
	public int afkTimeout;
	///The default method notification level of the guild
	public MessageNotificationLevel defaultMessageNotificationLevel;
	///The multi-factor authentication level of the guild
	public MFALevel mfaLevel;
	///The verification level of the guild
	public VerificationLevel verificationLevel;
	///The explicit content filter level of the guild
	public ExplicitContentFilterLevel explicitContentFilter;
	///A list of the ids of all `discord.types.Channel` in the guild
	public ulong[] channelIds;
	///A `discord.types.User` id indexed list of presences in this guild
	public Activity[ulong] presences;
	///A list of all `discord.types.Emoji`s in the guild
	public Emoji[] emojis;
	///A list of all `discord.types.GuildMember`s in the guild
	public GuildMember[] members;
	///A list of all `discord.types.Role`s in the guild
	public Role[] roles;
	//TODO features, joined at, voice states (maybe not voice states)
	this(Json json){
		updateInfo(json);
		if(json["presences"].type == Json.Type.array){
			foreach(Json j; json["presences"]){
				if(j["game"].type == Json.Type.null_) continue;
				ulong userId = j["user"]["id"].get!string.to!ulong;
				presences[userId] = Activity(j["game"]);
			}
		}
		members = json["members"][].map!(m => GuildMember(m)).array;
	}
	public void updateInfo(Json json){
		icon.safeAssign(json, "icon");
		name.safeAssign(json, "name");
		region.safeAssign(json, "region");
		splash.safeAssign(json, "splash");
		embedEnabled.safeAssign(json, "embed_enabled");
		large.safeAssign(json, "large");
		afkChannelId.safeAssign(json, "afk_channel_id");
		embedChannelId.safeAssign(json, "embed_channel_id");
		id.safeAssign(json, "id");
		ownerId.safeAssign(json, "owner_id");
		afkTimeout.safeAssign(json, "afk_timeout");
		if(json["default_message_notifications"].type == Json.Type.int_){
			defaultMessageNotificationLevel = cast(MessageNotificationLevel) json["default_message_notifications"].get!int;
		}
		if(json["mfa_level"].type == Json.Type.int_){
			mfaLevel = cast(MFALevel) json["mfa_level"].get!int;
		}
		if(json["verification_level"].type == Json.Type.int_){
			verificationLevel = cast(VerificationLevel) json["verification_level"].get!int;
		}
		if(json["explicit_content_filter"].type == Json.Type.int_){
			explicitContentFilter = cast(ExplicitContentFilterLevel) json["explicit_content_filter"].get!int;
		}
		emojis = json["emojis"][].map!(e => Emoji(e)).array;
		roles = json["roles"][].map!(r => Role(r)).array;
	}
	///A list of all `discord.types.Channel`s in the guild
	public @property Channel[] channels(){
		Channel[] c;
		foreach(i; channelIds){
			c ~= getChannel(i);
		}
		return c;
	}
	///Whether the afk `discord.types.Channel` exists
	public @property bool hasAfkChannel(){
		return afkChannelId != 0;
	}
	///The afk `discord.types.Channel` if it exists
	public @property Channel afkChannel(){
		return getChannel(afkChannelId);
	}
	///Whether the embed `discord.types.Channel` exists
	public @property bool hasEmbedChannel(){
		return embedChannelId != 0;
	}
	///The embed `discord.types.Channel` if it exists
	public @property Channel embedChannel(){
		return getChannel(embedChannelId);
	}
}
///A ban in a guild
struct Ban{
	///The reason for the ban (or an empty string if none provided)
	public Nullable!string reason;
	///A user instance with minimal fields
	public User user;
	this(Json json){
		reason.safeAssign(json, "reason");
		user = User(json["user"]);
	}
}
/**
* A role in a guild
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void roleInfo(Role role){
*		//Discord doesn't use #000000 as black
*		if(role.color == 0){
*			writeln("This role doesn't have a color and instead inherents its color");
*		}else{
*			//Calculate the color channels
*			int red = (color >> 16) & 255;
*			int green = (color >> 8) & 255;
*			int blue = color & 255;
*
*			//Print it out
*			writeln("This role's color is rgb(", red, ", ", green, ", ", blue, ")");
*		}
*	}
* ---
*/
struct Role{
	///The name of the role
	public string name;
	///The id of the role
	public ulong id;
	///Wheter the role is displayed separately
	public bool hoist;
	///Whether this role is managed
	public bool managed;
	///Whether you can @rolename the role
	public bool mentionable;
	///Hex color (0 is default color, not black)
	public int color;
	///The position of the role in the heirarchy
	public int position;
	///The permissions of the role
	public Permissions permissions;
	this(Json json){
		name = json["name"].get!string;
		id = json["id"].get!string.to!ulong;
		hoist = json["hoist"].get!bool;
		managed = json["managed"].get!bool;
		mentionable = json["mentionable"].get!bool;
		color = json["color"].get!int;
		position = json["position"].get!int;
		permissions = Permissions(json["permissions"].get!ulong);
	}
}
///A permissions structure (wrapper around a bitflag)
struct Permissions{//TODO maybe properly document this? It seems self-explanatory
	ulong permissions;
	this(ulong permissions){
		this.permissions = permissions;
	}
	///
	public @property bool createInstantInvite(){
		return (permissions & 0x1) != 0;
	}
	///
	public @property bool kickMembers(){
		return (permissions & 0x2) != 0;
	}
	///
	public @property bool banMembers(){
		return (permissions & 0x4) != 0;
	}
	///
	public @property bool administrator(){
		return (permissions & 0x8) != 0;
	}
	///
	public @property bool manageChannels(){
		return (permissions & 0x10) != 0;
	}
	///
	public @property bool manageGuild(){
		return (permissions & 0x20) != 0;
	}
	///
	public @property bool addReactions(){
		return (permissions & 0x40) != 0;
	}
	///
	public @property bool viewAuditLog(){
		return (permissions & 0x80) != 0;
	}
	///
	public @property bool viewChannel(){
		return (permissions & 0x400) != 0;
	}
	///
	public @property bool sendMessages(){
		return (permissions & 0x800) != 0;
	}
	///
	public @property bool sendTTSMessages(){
		return (permissions & 0x1000) != 0;
	}
	///
	public @property bool manageMessages(){
		return (permissions & 0x2000) != 0;
	}
	///
	public @property bool embedLinks(){
		return (permissions & 0x4000) != 0;
	}
	///
	public @property bool attachFiles(){
		return (permissions & 0x8000) != 0;
	}
	///
	public @property bool readMessageHistory(){
		return (permissions & 0x10000) != 0;
	}
	///
	public @property bool messageEveryone(){
		return (permissions & 0x20000) != 0;
	}
	///
	public @property bool useExternalEmojis(){
		return (permissions & 0x40000) != 0;
	}
	///
	public @property bool connect(){
		return (permissions & 0x100000) != 0;
	}
	///
	public @property bool speak(){
		return (permissions & 0x200000) != 0;
	}
	///
	public @property bool muteMembers(){
		return (permissions & 0x400000) != 0;
	}
	///
	public @property bool deafenMembers(){
		return (permissions & 0x800000) != 0;
	}
	///
	public @property bool moveMembers(){
		return (permissions & 0x1000000) != 0;
	}
	///
	public @property bool useVAD(){
		return (permissions & 0x2000000) != 0;
	}
	///
	public @property bool prioritySpeaker(){
		return (permissions & 0x100) != 0;
	}
	///
	public @property bool changeNickname(){
		return (permissions & 0x4000000) != 0;
	}
	///
	public @property bool manageNicknames(){
		return (permissions & 0x8000000) != 0;
	}
	///
	public @property bool manageRoles(){
		return (permissions & 0x10000000) != 0;
	}
	///
	public @property bool manageWebhooks(){
		return (permissions & 0x10000000) != 0;
	}
	///
	public @property bool manageEmojis(){
		return (permissions & 0x10000000) != 0;
	}
	///
	public @property void createInstantInvite(bool permission){
		if(permission) permissions |= 0x1;
		else permissions &= ~(0x1);
	}
	///
	public @property void kickMembers(bool permission){
		if(permission) permissions |= 0x2;
		else permissions &= ~(0x2);
	}
	///
	public @property void banMembers(bool permission){
		if(permission) permissions |= 0x4;
		else permissions &= ~(0x4);
	}
	///
	public @property void administrator(bool permission){
		if(permission) permissions |= 0x8;
		else permissions &= ~(0x8);
	}
	///
	public @property void manageChannels(bool permission){
		if(permission) permissions |= 0x10;
		else permissions &= ~(0x10);
	}
	///
	public @property void manageGuild(bool permission){
		if(permission) permissions |= 0x20;
		else permissions &= ~(0x20);
	}
	///
	public @property void addReactions(bool permission){
		if(permission) permissions |= 0x40;
		else permissions &= ~(0x40);
	}
	///
	public @property void viewAuditLog(bool permission){
		if(permission) permissions |= 0x80;
		else permissions &= ~(0x80);
	}
	///
	public @property void viewChannel(bool permission){
		if(permission) permissions |= 0x400;
		else permissions &= ~(0x400);
	}
	///
	public @property void sendMessages(bool permission){
		if(permission) permissions |= 0x800;
		else permissions &= ~(0x800);
	}
	///
	public @property void sendTTSMessages(bool permission){
		if(permission) permissions |= 0x1000;
		else permissions &= ~(0x1000);
	}
	///
	public @property void manageMessages(bool permission){
		if(permission) permissions |= 0x2000;
		else permissions &= ~(0x2000);
	}
	///
	public @property void embedLinks(bool permission){
		if(permission) permissions |= 0x4000;
		else permissions &= ~(0x4000);
	}
	///
	public @property void attachFiles(bool permission){
		if(permission) permissions |= 0x8000;
		else permissions &= ~(0x8000);
	}
	///
	public @property void readMessageHistory(bool permission){
		if(permission) permissions |= 0x10000;
		else permissions &= ~(0x10000);
	}
	///
	public @property void messageEveryone(bool permission){
		if(permission) permissions |= 0x20000;
		else permissions &= ~(0x20000);
	}
	///
	public @property void useExternalEmojis(bool permission){
		if(permission) permissions |= 0x40000;
		else permissions &= ~(0x40000);
	}
	///
	public @property void connect(bool permission){
		if(permission) permissions |= 0x100000;
		else permissions &= ~(0x100000);
	}
	///
	public @property void speak(bool permission){
		if(permission) permissions |= 0x200000;
		else permissions &= ~(0x200000);
	}
	///
	public @property void muteMembers(bool permission){
		if(permission) permissions |= 0x400000;
		else permissions &= ~(0x400000);
	}
	///
	public @property void deafenMembers(bool permission){
		if(permission) permissions |= 0x800000;
		else permissions &= ~(0x800000);
	}
	///
	public @property void moveMembers(bool permission){
		if(permission) permissions |= 0x1000000;
		else permissions &= ~(0x1000000);
	}
	///
	public @property void useVAD(bool permission){
		if(permission) permissions |= 0x2000000;
		else permissions &= ~(0x2000000);
	}
	///
	public @property void prioritySpeaker(bool permission){
		if(permission) permissions |= 0x100;
		else permissions &= ~(0x100);
	}
	///
	public @property void changeNickname(bool permission){
		if(permission) permissions |= 0x4000000;
		else permissions &= ~(0x4000000);
	}
	///
	public @property void manageNicknames(bool permission){
		if(permission) permissions |= 0x8000000;
		else permissions &= ~(0x8000000);
	}
	///
	public @property void manageRoles(bool permission){
		if(permission) permissions |= 0x10000000;
		else permissions &= ~(0x10000000);
	}
	///
	public @property void manageWebhooks(bool permission){
		if(permission) permissions |= 0x10000000;
		else permissions &= ~(0x10000000);
	}
	///
	public @property void manageEmojis(bool permission){
		if(permission) permissions |= 0x10000000;
		else permissions &= ~(0x10000000);
	}
}
/**
* A message in a channel
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void processMessage(Message message){
*		//Check if the message mentions @everyone
*		if(message.mentionsEveryone){
*			//:(
*			writeln(":(");
*		}
*	}
* ---
*/
struct Message{
	///The different types of messages (normal messages and special messages discord generates)
	public enum Type{
		Default = 0,
		RecipientAdd, RecipientRemove, Call,
		ChannelNameChange, ChannelIconChange, ChannelPinnedMessage, GuildMemberJoin,
		UserPremiumGuildSubscription, UserPremiumGuildSubscriptionTier1,
		UserPremiumGuildSubscriptionTier2, UserPremiumGuildSubscriptionTier3,
	}
	///The text content of the string
	public string content;
	///The id of the `discord.types.User` who sent the message
	public ulong authorId;
	///The id of the `discord.types.Channel` that the message is in
	public ulong channelId;
	///The id of the message
	public ulong id;
	///Whether the message mentions @everyone
	public bool mentionsEveryone;
	///Whether the message is pinned
	public bool pinned;
	///Whether the message is text to speech
	public bool tts;
	///The type of the message
	public Type type;
	this(Json json){
		content.safeAssign(json, "content");
		mentionsEveryone.safeAssign(json, "mention_everyone");
		pinned.safeAssign(json, "pinned");
		tts.safeAssign(json, "tts");
		channelId = json["channel_id"].get!string.to!ulong;
		id = json["id"].get!string.to!ulong;
		if(json["type"].type == Json.Type.int_) type = cast(Type) json["type"].get!int;
		if(json["author"].type == Json.Type.object) authorId = json["author"]["id"].get!string.to!ulong;
	}
	///The channel this message is in
	public @property Channel channel(){
		return getChannel(channelId);
	}
	///The `discord.types.User` who sent the message
	public @property User author(){
		return getUser(authorId);
	}
}
/**
* A user in a guild
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void checkNickname(GuildMember member){
*		//Check if the member has a nickname
*		if(member.nick != ""){
*			//The member has a nickname, use that
*			writeln("This user's display name is ", member.nick);
*		}else{
*			//The member doesn't have a nickname, use their username
*			writeln("This user's display name is ", member.user.username);
*		}
*	}
* ---
*/
struct GuildMember{
	///The member's guild-specific nickname
	public Nullable!string nick;
	///The timestamp when the member joined at
	public string joinedAt;
	///List of role ids the member has
	public ulong[] roleIds;
	///Whether the member is deafened
	public bool deaf;
	///Whether the member is muted
	public bool mute;
	///The id of the member's `discord.types.User`
	public ulong userId;
	this(Json json){
		nick.safeAssign(json, "nick");
		joinedAt.safeAssign(json, "joined_at");
		deaf = json["deaf"].get!bool;
		mute = json["mute"].get!bool;
		roleIds = json["roles"][].map!(r => r.get!string.to!ulong).array;
		userId = json["user"]["id"].get!string.to!ulong;
	}
	///The member's `discord.types.User` instance
	public @property User user(){
		return getUser(userId);
	}
	///The member's display name, either their username or nickname if present
	public @property string displayName(){
		if(!nick.isNull) return nick;
		return user.username;
	}
}
/**
* A user
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void examineUser(User user){
*		//Print the user's name with discriminator
*		writeln(user.username ~ "#" ~ user.discriminator);
*
*		//Worship Discord employees
*		if(user.employee) writeln("All hail the mighty Discord employee!");
*	}
* ---
*/
struct User{
	///The four digit discriminator of the user
	public string discriminator;
	///The email of the user (unavailable without email scope)
	public Nullable!string email;
	///The chosen language option of the user
	public Nullable!string locale;
	///The username of the user
	public string username;
	///The id of the user
	public ulong id;
	///Whether the user is a bot
	public Nullable!bool bot;
	///Whether the user has multifactor authentication enabled
	public Nullable!bool mfaEnabled;
	///Whether the user is verified
	public bool verified;
	///The flags on the account of the user
	public Nullable!int flags;
	///The type of premium the user has
	public Nullable!int premiumType;
	this(Json json){
		discriminator = json["discriminator"].get!string;
		email.safeAssign(json, "email");
		locale.safeAssign(json, "locale");
		username = json["username"].get!string;
		id = json["id"].get!string.to!ulong;
		bot.safeAssign(json, "bot");
		mfaEnabled.safeAssign(json, "mfa_enabled");
		verified.safeAssign(json, "verified");
		flags.safeAssign(json, "flags");
		premiumType.safeAssign(json, "premium_type");
	}
	///Whether the user is a Discord employee
	public @property bool employee(){
		return (flags | (1 << 0)) != 0;
	}
	///Whether the user is a Discord partner
	public @property bool partner(){
		return (flags | (1 << 1)) != 0;
	}
	///Whether the user is a HypeSquad Events member
	public @property bool hypeSquadEvents(){
		return (flags | (1 << 2)) != 0;
	}
	///Whether the user is a Bug Hunter
	public @property bool bugHunter(){
		return (flags | (1 << 3)) != 0;
	}
	///Whether the user is a House Bravery member
	public @property bool houseBravery(){
		return (flags | (1 << 6)) != 0;
	}
	///Whether the user is a House Brilliance member
	public @property bool houseBrilliance(){
		return (flags | (1 << 7)) != 0;
	}
	///Whether the user is a House Balance member
	public @property bool houseBalance(){
		return (flags | (1 << 8)) != 0;
	}
	///Whether the user is an Early Supporter
	public @property bool earlySupporter(){
		return (flags | (1 << 9)) != 0;
	}
}
/**
* An activity on a user, currently lacking rich game info
* Examples:
* ---
*	import std.stdio: writeln;
*
*	void checkActivity(Activity activity){
*		//Print the activity status
*		if(activity.type == Activity.Type.None){
*			writeln("No activity!");
*		}else if(activity.type == Activity.Type.Game){
*			writeln("Playing " ~ activity.name);
*		}else if(activity.type == Activity.Type.Stream){
*			writeln("Streaming " ~ activity.name ~ " at " ~ activity.url);
*		}else if(activity.type == Activity.Type.Listening){//Always Spotify
*			writeln("Listening to " ~ activity.name);
*		}
*	}
* ---
*/
struct Activity{//TODO missing rich game info
	///The different types of activities
	public enum Type{
		Game = 0, Streaming = 1, Listening = 2
	}
	///The name of the activity
	public string name;
	///The url of the activity if this activity is a stream (only twitch.tv urls)
	public Nullable!string url;
	///The type of the activity
	public Nullable!Type type;
	this(Json json){
		name = json["name"].get!string;
		type = cast(Type) json["type"].get!int;
		if(type == 1) url.safeAssign(json, "url");
	}
}
/**
* An emoji in a guild
* Examples:
* ---
*	//Initialized elsewhere
*	DiscordBot bot;
*
*	void useEmoji(Emoji emoji, Message message){
*		//Send a message containing the emoji
*		bot.sendMessage(message.channelId, "Looking for " ~ emoji.textCode ~ "?");
*		
*		//React to a message with the emoji
*		bot.createReaction(emoji);
*	}
* ---
*/
struct Emoji{
	///The name of the emoji
	public string name;
	///The ids of the roles whitelisted for the emoji
	public ulong[] roleIds;
	///The id of the emoji if custom
	public Nullable!ulong id;
	///The id of the user who created the emoji
	public Nullable!ulong userId;
	///Whether the emoji is animated
	public Nullable!bool animated;
	///Whether the emoji is managed
	public Nullable!bool managed;
	///Whether the emoji requires colons
	public Nullable!bool requireColons;
	this(Json json){
		name = json["name"].get!string;
		if(json["id"].type != Json.Type.null_) id = json["id"].get!string.to!ulong;
		if(json["user"].type != Json.Type.undefined && json["user"]["id"].type != Json.Type.undefined) userId = json["user"]["id"].get!string.to!ulong;
		animated.safeAssign(json, "animated");
		managed.safeAssign(json, "managed");
		requireColons.safeAssign(json, "require_colons");
		if(json["roles"].type != Json.Type.undefined) roleIds = json["roles"][].map!(r => r.get!string.to!ulong).array;
	}
	///Initiallize as unicode emoji
	this(string name){
		this.name = name;
	}
	///Whether the emoji is custom
	public @property bool custom(){
		return !id.isNull;
	}
	///The rich name of the emoji in the format name:id, used by reaction endpoints
	public @property string richName(){
		if(!custom) return name;
		else return name ~ ":" ~ userId.to!string;
	}
	///The text code for an emoji, to be used in message content in the format <name:id>
	public @property string textCode(){
		if(!custom) return name;
		else return "<" ~ name ~ ":" ~ userId.to!string ~ ">";
	}
	public const bool opEquals(Emoji e){
		return name == e.name && id == e.id;
	}
	public const bool opEquals(string s){
		return id.isNull && name == s;
	}
}
//I haven't decided if I think this is a terrible hack but I think that I've decided that it's terrible
//Checks that the value exists in the Json before assigning it, probably can cause other problems though
private void safeAssign(T)(ref T var, Json json, string name){
	static if(is(T == Nullable!U, U)){
		static if(is(U == ulong)){
			if(json[name].type != Json.Type.null_ && json[name].type != Json.Type.undefined) var = json[name].get!string.to!U;
		}else{
			if(json[name].type != Json.Type.null_ && json[name].type != Json.Type.undefined) var = json[name].get!U;
		}
	}else{
		static if(is(T == ulong)){
			if(json[name].type != Json.Type.null_ && json[name].type != Json.Type.undefined) var = json[name].get!string.to!T;
		}else{
			if(json[name].type != Json.Type.null_ && json[name].type != Json.Type.undefined) var = json[name].get!T;
		}
	}
}