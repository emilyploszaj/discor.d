/**
* The event handler for Discord websocket events to be overwritten by library users
* Authors:
*	Emily Rose Ploszaj
*/
module discord.events;

import discord.types;
import vibe.data.json;
import vibe.http.client;

/**
* Class to be implemented and overwritten by user to handle events received by the Discord websocket API
* Examples:
* ---
*	//token variable initialized elsewhere
*	DiscordBot bot = new DiscordBot(token, new MyDiscordEvents());
*
*	//Custom class to recieve and handle discord events
*	class MyDiscordEvents: DiscordEvents{
*		//Keep a record of which messages we've seen (lazy implementation, message ids are not guarenteed to be unique)
*		bool[ulong] messagesSeen;
*
*		//Handle messages getting sent
*		public void messageCreate(Message message){
*			writeln("Message was sent in channel with the id:", message.channelId);
*
*			//Adds this message to the list
*			messagesSeen[message.id] = true;
*		}
*
*		//Handle messages getting deleted
*		public void messageDelete(Channel channel, ulong id){
*			//Check to see if we've seen the message in this session
*			if(id in messagesSeen){
*				writeln("Uh oh, someone didn't want us to see that");
*				
*				//Does not remove this message from the list, simply marks it as deleted
*				messagesSeen[id] = false;
*			}
*		}
*	}
* ---
*/
class DiscordEvents{
	/**
	* Called when an action is rate limited
	* Params:
	*	url =		The url the request was sent to
	*	method =	The HTTPMethod type used
	*	message =	The message to be sent
	*/
	public void actionRateLimited(string url, HTTPMethod method, Json message){
	}
	/**
	* Called when the bot is about to shut down, should be used to clean up if needed (this can be called from no thread if a SIGINT is intercepted, __gshared might be needed for accessed data)
	*/
	public void shutDown(){
	}
	/**
	* Called when a channel is created
	* Params:
	*	channel =	The `discord.types.Channel` instance created
	*/
	public void channelCreate(Channel channel){
	}
	/**
	* Called when a channel is updated
	* Params:
	*	channel =	The `discord.types.Channel` instance updated
	*/
	public void channelUpdate(Channel channel){
	}
	/**
	* Called when a channel is deleted
	* Params:
	*	channel =	The `discord.types.Channel` instance deleted
	*/
	public void channelDelete(Channel channel){
	}
	/**
	* Called when a channel's pinned messages are updated, information about this change has to be manually requested
	* Params:
	*	channel =	The `discord.types.Channel` where pins were updated
	*/
	public void pinsUpdate(Channel channel){
	}
	/**
	* Called when either:
	*	The user initially is connecting and the guild data is first recieved
	*	The guild becomes available
	*	The user joins a new guild
	* Params:
	*	guild =		The `discord.types.Guild` that has been 'created'
	*/
	public void guildCreate(Guild guild){
	}
	/**
	* Called when a guild is updated
	* Params:
	*	guild =		The `discord.types.Guild` that has been updated
	*/
	public void guildUpdate(Guild guild){
	}
	/**
	* Called when a guild is no longer accessible by a user
	* Params:
	*	guild =		The `discord.types.Guild` is no longer available 
	*	removed =	`true` if the user was removed from the `discord.types.Guild` (leave/kick/ban), `false` otherwise
	*/
	public void guildDelete(Guild guild, bool removed){
	}
	/**
	* Called when a user has been banned from the guild
	* Params:
	*	guild =		The `discord.types.Guild` where the user was banned
	*	user =		The `discord.types.User` that was banned
	*/
	public void guildBanAdd(Guild guild, User user){
	}
	/**
	* Called when a user has been unbanned from the guild
	* Params:
	*	guild =		The `discord.types.Guild` where the user was unbanned
	*	user =		The `discord.types.User` that was unbanned
	*/
	public void guildBanRemove(Guild guild, User user){
	}
	/**
	* Called when a guild's emojis are updated
	* Params:
	*	guild =		The `discord.types.Guild` where `discord.types.Emoji`s were updated
	*/
	public void guildEmojisUpdate(Guild guild){
	}
	/**
	* Called when a user joins a guild
	* Params:
	*	guild =		The `discord.types.Guild` where integrations were updated
	*/
	public void guildIntegrationsUpdate(Guild guild){
	}
	/**
	* Called when a user joins a guild
	* Params:
	*	guild =		The `discord.types.Guild` where the member joined
	*	member =	The `discord.types.GuildMember` that joined
	*/
	public void guildMemberAdd(Guild guild, GuildMember member){
	}
	/**
	* Called when a user is removed from a guild (leave/kick/ban)
	* Params:
	*	guild =		The `discord.types.Guild` where the member was removed from
	*	member =	The `discord.types.GuildMember` that was removed
	*/
	public void guildMemberRemove(Guild guild, GuildMember member){
	}
	/**
	* Called when a user is updated in a guild
	* Params:
	*	guild =		The `discord.types.Guild` where the member was updated
	*	member =	The `discord.types.GuildMember` that was updated
	*/
	public void guildMemberUpdate(Guild guild, GuildMember member){
	}
	/**
	* Called when a role is created in a guild
	* Params:
	*	guild =		The `discord.types.Guild` where the role was created
	*	role =		The `discord.types.Role` that was created
	*/
	public void guildRoleCreate(Guild guild, Role role){
	}
	/**
	* Called when a role is updated in a guild
	* Params:
	*	guild =		The `discord.types.Guild` where the role was updated
	*	role =		The `discord.types.Role` that was updated
	*/
	public void guildRoleUpdate(Guild guild, Role role){
	}
	/**
	* Called when a role is deleted in a guild
	* Params:
	*	guild =		The `discord.types.Guild` where the role was deleted
	*	role =		The `discord.types.Role` that was deleted
	*/
	public void guildRoleDelete(Guild guild, Role role){
	}
	/**
	* Called when a message is created in a channel the current bot user can view
	* Params:
	*	message = 	The `discord.types.Message` that was created
	*/
	public void messageCreate(Message message){
	}
	/**
	* Called when a message is edited, contains only information about the new message content
	* Params:
	*	message =	The `discord.types.Message` that was created
	*/
	public void messageUpdate(Message message){
	}
	/**
	* Called when a message is deleted, contains no information about the old message
	* Params:
	*	channel =	The `discord.types.Channel` where the message was deleted from
	*	id = 		The id of the message that was deleted
	*/
	public void messageDelete(Channel channel, ulong id){
	}
	/**
	* Called when many messages were deleted in bulk, often by a bot user
	* Params:
	*	channel =	The `discord.types.Channel` where the messages were deleted from
	*	ids =		An array of ids of the deleted messages
	*/
	public void messageDeleteBulk(Channel channel, ulong[] ids){
	}
	/**
	* Called when a reaction is added to a message
	* Params:
	*	channel =	The `discord.types.Channel` where the `discord.types.Message` that was reacted to is in
	*	messageId =	The id of the `discord.types.Message` that was reacted to
	*	userId =	The id of the `discord.types.User` who reacted
	*	emoji =		The `discord.types.Emoji` that was reacted
	*/
	public void messageReactionAdd(Channel channel, ulong messageId, ulong userId, Emoji emoji){
	}
	/**
	* Called when a reaction is removed from a message
	* Params:
	*	channel =	The `discord.types.Channel` where the `discord.types.Message` that had a reaction removed from is in
	*	messageId =	The id of the `discord.types.Message` that had a reaction removed from it
	*	userId =	The id of the `discord.types.User` who removed the reaction
	*	emoji =		The `discord.types.Emoji` that was removed
	*/
	public void messageReactionRemove(Channel channel, ulong messageId, ulong userId, Emoji emoji){
	}
	/**
	* Called when a message has all of its reactions removed
	* Params:
	*	channel =	The `discord.types.Channel` where the `discord.types.Message` that had its reactions deleted is in
	*	messageId =	The id of the `discord.types.Message` that had its reactions deleted 
	*/
	public void messageReactionRemoveAll(Channel channel, ulong messageId){
	}
	/**
	* Called when a user updates their precense
	* Params:
	*	guild =		The `discord.types.Guild` that the user was updated in
	*	userId =	The id of the `discord.types.User` whose presence was updated
	*	roles =		The `discord.types.Role`s the user has
	*	activity =	The `discord.types.Activity` the user is playing
	*	status =	The status the user has, one of "idle", "dnd", "online", or "offline"
	*/
	public void presenceUpdate(Guild guild, ulong userId, Role[] roles, Activity activity, string status){
	}
	/**
	* Called when a user starts typing
	* Params:
	*	channel =	The `discord.types.Channel` the user started typing in
	*	userId =	The id of the `discord.types.User` that started typing
	*/
	public void typingStart(Channel channel, ulong userId){
	}
}