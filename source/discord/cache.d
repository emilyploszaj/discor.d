/**
* The thread local cache of `discord.types.Channel`s, `discord.types.Guild`s, and `discord.types.User`s
* Examples:
* ---
*	//Initialized elsewhere
*	DiscordBot bot;
*
*	//Get all channels
*	Channel[] listOfChannels = getAllChannels();
*
*	import std.stdio: writeln;
*	import std.algorithm.iteration: each;
*	
*	//Prints out all channel names
*	listOfChannels.each!(channel => channel.name.writeln());
* ---
* Authors:
*	Emily Rose Ploszaj
*/
module discord.cache;

import discord.types;
import std.conv;
import std.typecons;

private Guild[ulong] guilds;
private Channel[ulong] channels;
private User[ulong] users;

void addCachedChannel(Channel channel){
	channels[channel.id] = channel;
}
void addCachedGuild(Guild guild){
	guilds[guild.id] = guild;
}
void addCachedUser(User user){
	users[user.id] = user;
}
void modifyCachedChannel(ulong id, void delegate(ref Channel channel) del){
	del(channels[id]);
}
void modifyCachedGuild(ulong id, void delegate(ref Guild guild) del){
	del(guilds[id]);
}
void modifyCachedUser(ulong id, void delegate(ref User user) del){
	del(users[id]);
}
void removeCachedChannel(ulong id){
	channels.remove(id);
}
void removeCachedGuild(ulong id){
	guilds.remove(id);
}
void removeCachedUser(ulong id){//I don't think this should ever be called
	users.remove(id);
}
/**
* Gets a cached channel from id
* Params:
*	id =		The id of the `discord.types.Channel` to get
* Returns:
*	The `discord.types.Channel` specified by its id
*/
Nullable!Channel getChannel(ulong id){
	if(id in channels){
		return cast(Nullable!Channel) channels[id];
	}else{
		return Nullable!Channel.init;
	}
}
/**
* Gets a cached guild from id
* Params:
*	id =		The id of the `discord.types.Guild` to get
* Returns:
*	The `discord.types.Guild` specified by its id
*/
Nullable!Guild getGuild(ulong id){
	if(id in guilds){
		return cast(Nullable!Guild) guilds[id];
	}else{
		return Nullable!Guild.init;
	}
}
/**
* Gets a cached user from id
* Params:
*	id =		The id of the `discord.types.User` to get
* Returns:
*	The `discord.types.User` specified by its id
*/
Nullable!User getUser(ulong id){
	if(id in users){
		return cast(Nullable!User) users[id];
	}else{
		return Nullable!User.init;
	}
}
/**
* Gets all cached channels
* Returns:
*	An array of all `discord.types.Channel`s in the cache
*/
Channel[] getAllChannels(){
	return channels.values;
}
/**
* Gets all cached guilds
* Returns:
*	An array of all `discord.types.Guild`s in the cache
*/
Guild[] getAllGuilds(){
	return guilds.values;
}
/**
* Gets all cached users
* Returns:
*	An array of all `discord.types.User`s in the cache
*/
User[] getAllUsers(){
	return users.values;
}