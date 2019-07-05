module discord.cache;

import discord.types;
import std.conv;

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
Channel getChannel(ulong id){
	if(id in channels){
		return channels[id];
	}else{
		throw new Exception("Channel id " ~ id.to!string ~ " not located in cache");
	}
}
Guild getGuild(ulong id){
	if(id in guilds){
		return guilds[id];
	}else{
		throw new Exception("Guild id " ~ id.to!string ~ " not located in cache");
	}
}
User getUser(ulong id){
	if(id in users){
		return users[id];
	}else{
		throw new Exception("User id " ~ id.to!string ~ " not located in cache");
	}
}
Channel[] getAllChannels(){
	return channels.values;
}
Guild[] getAllGuilds(){
	return guilds.values;
}
User[] getAllUsers(){
	return users.values;
}