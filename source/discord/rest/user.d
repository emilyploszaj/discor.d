/**
* A subset of the Discord REST API function calls for users including methods to modify users, leave guilds, and create DMs
*
* All methods are available in a `discord.bot.DiscordBot` instance and cannot be called from anywhere in `discord.rest.user`
* See_Also:
*	`discord.bot.DiscordBot`
* Authors:
*	Emily Rose Ploszaj
*/
module discord.rest.user;

import discord.bot;
import std.conv;
import vibe.data.json;
import vibe.http.client;


/**
* The template mixin to deal with all REST requests delegated user requests, all methods are available in a `discord.bot.DiscordBot` instance
* Examples:
*	---
*	//Initialized elsewhere
*	DiscordBot bot;
*
*	//The only guild the current bot user is in, initialized elsewhere
*	Guild guild;
*
*	//Message handler
*	void messageCreate(Message m){
*		//Leave when asked politely
*		if(m.content == "get lost"){
*			//Assume guild is the only guild the bot is in
*			bot.leaveGuild(guild);
*		}
*
*		//Send a fun message to anyone who asks
*		if(m.content == "talk to me"){
*			//Create a DM
*			Channel dmChannel = bot.createDM(m.author);
*
*			//Say something funny
*			bot.sendMessage(dmChannel, "I enjoy pants (this is a joke)");
*		}
*	}
*	---
*/
mixin template RestUser(alias requestResponse){
	/**
	* Gets the instance of the bot account currently being used
	* Returns:
	*	The current `discord.types.User` (or an empty `discord.types.User` if an error occurs)
	*/
	public User getCurrentUser(){
		User user;
		requestResponse("users/@me", HTTPMethod.GET, Json.emptyObject, RouteType.Global, 0, (scope res){
			user = User(res.readJson());
		});
		return user;
	}
	/**
	* Gets the instance of a user from id
	* Params:
	*	user =		The id of the `discord.types.User` to get	
	* Returns:
	*	The specified `discord.types.User` (or an empty `discord.types.User` if an error occurs)
	*/
	public User getUser(ulong user){
		User result;
		requestResponse("users/" ~ user.to!string, HTTPMethod.GET, Json.emptyObject, RouteType.Global, 0, (scope res){
			if(res.statusCode != 200) return;
			result = User(res.readJson());
		});
		return result;
	}
	/**
	* Modifies the username of the current bot account
	* Params:
	*	username =	The username to be changed to (Note: this may result in a changed discriminator)
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyCurrentUser(string username){//TODO other parts of a user
		return requestResponse("users/@me", HTTPMethod.PATCH, Json(["username": Json(username)]));
	}
	/**
	* Leaves a guild (Note: this can not be undone, bot accounts will need to be re-added by owners)
	* Params:
	*	guild =		The `discord.types.Guild` to be left
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool leaveGuild(Guild guild){
		return leaveGuild(guild.id);
	}
	/// ditto
	public bool leaveGuild(ulong guild){
		return requestResponse("users/@me/guilds/" ~ guild.to!string, HTTPMethod.DELETE);
	}
	/**
	* Creates a DM with another user
	* Params:
	*	user =		The `discord.types.User` to start a DM with
	* Returns:
	*	The `discord.types.Channel` object (or an empty `discord.types.Channel` if an error occurs)
	*/
	public Channel createDM(User user){
		return createDM(user.id);
	}
	///ditto
	public Channel createDM(ulong user){
		Channel channel;
		requestResponse("users/@me/channels", HTTPMethod.POST, Json(["recipient_id": Json(user)]), RouteType.Global, 0, (scope res){
			if(res.statusCode != 200) return;
			channel = Channel(res.readJson());
		});
		return channel;
	}

	//TODO createGroupDM
	
	//TODO getUserConnection

}