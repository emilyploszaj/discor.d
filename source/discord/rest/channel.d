/**
* A subset of the Discord REST API function calls for channels including methods to modify channels, send messages to channels, and interact with messages in channels
*
* All methods are available in a `discord.bot.DiscordBot` instance and cannot be called from anywhere in `discord.rest.channel`
* See_Also:
*	`discord.bot.DiscordBot`
* Authors:
*	Emily Rose Ploszaj
*/
module discord.rest.channel;

import discord.bot;
import std.algorithm;
import std.conv;
import vibe.data.json;
import vibe.http.client;

/**
* The template mixin to deal with all REST requests delegated channel requests, all methods are available in a `discord.bot.DiscordBot` instance
* Examples:
*	---
*	//Initialized elsewhere
*	DiscordBot bot;
*
*	//Message handler
*	void messageCreate(Message m){
*		//Say hi to Ally if she says something
*		if(m.author.username == "Ally"){
*			bot.sendMessage(m.channelId, "hi Ally!");
*		}
*
*		import std.string:indexOf;
*		//React to Grace's messages that contain the word "emoji" in them
*		if(m.author.username == "Grace" && m.content.indexOf("emoji") != -1){
*			//Define an Emoji
*			Emoji e = Emoji("💁");
*
*			//You can also call this method with a string
*			//bot.addReaction(m, "💁");
*			bot.addReaction(m, e);
*		}
*	}
*	---
*/
mixin template RestChannel(alias requestResponse){
	/**
	* Modifies a channel using local changes
	* Params:
	*	channel =	A locally modified `discord.types.Channel` object
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyChannel(Channel channel){
		Json json = Json([
			"name": Json(channel.name),
			"position": Json(channel.position),
			"topic": Json(channel.topic),
			"nsfw": Json(channel.nsfw),
			"rate_limit_per_user": Json(channel.rateLimitPerUser),
			"bitrate": Json(channel.bitrate),
			"user_limit": Json(channel.userLimit),
			//TODO missing: "permission_overwrites"
			"parent_id": Json(channel.parentId)
		]);
		return requestResponse("channels/" ~ to!string(channel.id), HTTPMethod.PATCH, json, RouteType.Channel, channel.id);
	}
	/**
	* Deletes a channel or closes a DM, deleting a channel cannot be undone, procede with caution
	* Params:
	*	channel =	The `discord.types.Channel` to delete
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteChannel(Channel channel){
		return deleteChannel(channel.id);
	}
	/// ditto
	public bool deleteChannel(ulong channel){
		return requestResponse("channels/" ~ to!string(channel), HTTPMethod.DELETE, Json.emptyObject, RouteType.Channel, channel);
	}

	//TODO getChannelMessages

	/**
	* Returns a message from id
	* Params:
	*	channel =	The `discord.types.Channel` where the `discord.types.Message` is
	*	message =	The id of the `discord.types.Message`
	* Returns:
	*	The `discord.types.Message` specified (or a blank `discord.types.Message` if it doesn't exist or can't be accessed)
	*/
	public Message getMessage(Channel channel, ulong message){
		return getMessage(channel.id, message);
	}
	/// ditto
	public Message getMessage(ulong channel, ulong message){
		Message result;
		requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message), HTTPMethod.GET, Json.emptyObject, RouteType.Channel, channel, (scope res){
			if(res.statusCode != 200) return;
			result = Message(res.readJson());
		});
		return result;
	}
	/**
	* Sends a message in a channel
	* Params:
	*	channel =	The `discord.types.Channel` to send a message to
	*	message =	The text content of the message
	*	embed =		The rich embed content of the message
	* Returns:
	*	`true` if successful, `false` otherwise
	* See_Also:
	*	$(LINK https://discordapp.com/developers/docs/resources/channel#embed-object)
	*/
	public bool sendMessage(Channel channel, string message){
		return sendMessage(channel.id, message);
	}
	/// ditto
	public bool sendMessage(ulong channel, string message){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages", HTTPMethod.POST, Json(["content": Json(message)]), RouteType.Channel, channel);
	}
	/// ditto
	public bool sendMessage(Channel channel, string message, Json embed){
		return sendMessage(channel.id, message, embed);
	}
	/// ditto
	public bool sendMessage(ulong channel, string message, Json embed){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages", HTTPMethod.POST, Json(["content": Json(message), "embed": embed]), RouteType.Channel, channel);
	}

	//TODO maybe change sendMessge to createMessage? or make an alias

	/**
	* Adds an emoji reaction to a message
	* Params:
	*	channel =	The `discord.types.Channel` where the message is
	*	message =	The `discord.types.Message` to add a reaction to
	*	emoji =		The `discord.types.Emoji` to add to the message, if passing a string, in the format "name:id" for custom emoji or Unicode characters
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool createReaction(Message message, Emoji emoji){
		return createReaction(message.channelId, message.id, emoji.richName);
	}
	/// ditto
	public bool createReaction(Channel channel, ulong message, Emoji emoji){
		return createReaction(channel.id, message, emoji.richName);
	}
	/// ditto
	public bool createReaction(ulong channel, ulong message, Emoji emoji){
		return createReaction(channel, message, emoji.richName);
	}
	/// ditto
	public bool createReaction(Message message, string emoji){
		return createReaction(message.channelId, message.id, emoji);
	}
	/// ditto
	public bool createReaction(Channel channel, ulong message, string emoji){
		return createReaction(channel.id, message, emoji);
	}
	/// ditto
	public bool createReaction(ulong channel, ulong message, string emoji){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message) ~ "/reactions/" ~ emoji ~ "/@me", HTTPMethod.PUT, Json.emptyObject, RouteType.Channel, channel);
	}
	/**
	* Removes an emoji reaction from a message
	* Params:
	*	channel =	The `discord.types.Channel` where the message is
	*	message =	The `discord.types.Message` to remove a reaction from
	*	emoji =		The `discord.types.Emoji` to remove from the message, if passing a string, in the format "name:id" for custom emoji or Unicode characters
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteOwnReaction(Message message, string emoji){
		return deleteOwnReaction(message.channelId, message.id, emoji);
	}
	/// ditto
	public bool deleteOwnReaction(Channel channel, ulong message, string emoji){
		return deleteOwnReaction(channel.id, message, emoji);
	}
	/// ditto
	public bool deleteOwnReaction(ulong channel, ulong message, string emoji){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message) ~ "/reactions/" ~ emoji ~ "/@me", HTTPMethod.DELETE, Json.emptyObject, RouteType.Channel, channel);
	}
	/**
	* Removes an emoji reaction from another user from a message
	* Params:
	*	channel =	The `discord.types.Channel` where the message is
	*	user =		The `discord.types.User` that made the reaction
	*	message =	The `discord.types.Message` to remove a reaction from
	*	emoji =		The `discord.types.Emoji` to remove from the message, if passing a string, in the format "name:id" for custom emoji or Unicode characters
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteUserReaction(User user, Message message, Emoji emoji){
		return deleteUserReaction(message.channelId, user.id, message.id, emoji.richName);
	}
	/// ditto
	public bool deleteUserReaction(ulong user, Message message, Emoji emoji){
		return deleteUserReaction(message.channelId, user, message.id, emoji.richName);
	}
	/// ditto
	public bool deleteUserReaction(Channel channel, User user, ulong message, Emoji emoji){
		return deleteUserReaction(channel.id, user.id, message, emoji.richName);
	}
	/// ditto
	public bool deleteUserReaction(Channel channel, ulong user, ulong message, Emoji emoji){
		return deleteUserReaction(channel.id, user, message, emoji.richName);
	}
	/// ditto
	public bool deleteUserReaction(ulong channel, User user, ulong message, Emoji emoji){
		return deleteUserReaction(channel, user.id, message, emoji.richName);
	}
	/// ditto
	public bool deleteUserReaction(ulong channel, ulong user, ulong message, Emoji emoji){
		return deleteUserReaction(channel, user, message, emoji.richName);
	}
	/// ditto
	public bool deleteUserReaction(User user, Message message, string emoji){
		return deleteUserReaction(message.channelId, user.id, message.id, emoji);
	}
	/// ditto
	public bool deleteUserReaction(ulong user, Message message, string emoji){
		return deleteUserReaction(message.channelId, user, message.id, emoji);
	}
	/// ditto
	public bool deleteUserReaction(Channel channel, User user, ulong message, string emoji){
		return deleteUserReaction(channel.id, user.id, message, emoji);
	}
	/// ditto
	public bool deleteUserReaction(Channel channel, ulong user, ulong message, string emoji){
		return deleteUserReaction(channel.id, user, message, emoji);
	}
	/// ditto
	public bool deleteUserReaction(ulong channel, User user, ulong message, string emoji){
		return deleteUserReaction(channel, user.id, message, emoji);
	}
	/// ditto
	public bool deleteUserReaction(ulong channel, ulong user, ulong message, string emoji){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message) ~ "/reactions/" ~ emoji ~ "/" ~ to!string(user), HTTPMethod.DELETE, Json.emptyObject, RouteType.Channel, channel);
	}

	//TODO getReactions

	/**
	* Removes all emoji reactions from a message
	* Params:
	*	channel =	The `discord.types.Channel` where the message is
	*	message =	The `discord.types.Message` to remove reactions from
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteAllReactions(Message message){
		return deleteAllReactions(message.channelId, message.id);
	}
	/// ditto
	public bool deleteAllReactions(Channel channel, Message message){
		return deleteAllReactions(channel.id, message.id);
	}
	/// ditto
	public bool deleteAllReactions(Channel channel, ulong message){
		return deleteAllReactions(channel.id, message);
	}
	/// ditto
	public bool deleteAllReactions(ulong channel, ulong message){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message) ~ "/reactions", HTTPMethod.DELETE, Json.emptyObject, RouteType.Channel, channel);
	}
	/**
	* Edits a message
	* Params:
	*	channel =	The `discord.types.Channel` where the message to be edited is
	*	message =	The `discord.types.Message` to be edited
	*	content =	The text content of the new message
	*	embed =		The rich embed content of the new message
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool editMessage(Message message, string content){
		return editMessage(message.channelId, message.id, content);
	}
	/// ditto
	public bool editMessage(Channel channel, Message message, string content){
		return editMessage(channel.id, message.id, content);
	}
	/// ditto
	public bool editMessage(Channel channel, ulong message, string content){
		return editMessage(channel.id, message, content);
	}
	/// ditto
	public bool editMessage(ulong channel, ulong message, string content){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message), HTTPMethod.PATCH, Json(["content": Json(content)]), RouteType.Channel, channel);
	}
	/// ditto
	public bool editMessage(Message message, string content, Json embed){
		return editMessage(message.channelId, message.id, content, embed);
	}
	/// ditto
	public bool editMessage(Channel channel, Message message, string content, Json embed){
		return editMessage(channel.id, message.id, content, embed);
	}
	/// ditto
	public bool editMessage(Channel channel, ulong message, string content, Json embed){
		return editMessage(channel.id, message, content, embed);
	}
	/// ditto
	public bool editMessage(ulong channel, ulong message, string content, Json embed){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message), HTTPMethod.PATCH, Json(["content": Json(content), "embed": embed]), RouteType.Channel, channel);
	}
	/**
	* Deletes a message
	* Params:
	*	channel =	The `discord.types.Channel` where the `discord.types.Message` is
	*	message =	The `discord.types.Message` to delete
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteMessage(Message message){
		return deleteMessage(message.channelId, message.id);
	}
	/// ditto
	public bool deleteMessage(Channel channel, ulong message){
		return deleteMessage(channel.id, message);
	}
	/// ditto
	public bool deleteMessage(ulong channel, ulong message){
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/" ~ to!string(message), HTTPMethod.DELETE, Json.emptyObject, RouteType.Channel, channel);
	}
	/**
	* Deletes between 2-100 messages at once from a single channel that are not older than 2 weeks old, will return `false` if passed array doesn't fall into this range
	* Params:
	*	channel =	The `discord.types.Channel` the messages are in
	*	messages =	The `discord.types.Message`s to be deleted
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool bulkDeleteMessages(Message[] messages){
		if(messages.length < 2 || messages.length > 100) return false;
		return bulkDeleteMessages(messages[0].channelId, messages.map!(m => m.id).array);
	}
	/// ditto
	public bool bulkDeleteMessages(Channel channel, ulong[] messages){
		if(messages.length < 2 || messages.length > 100) return false;
		return bulkDeleteMessages(channel.id, messages);
	}
	/// ditto
	public bool bulkDeleteMessages(ulong channel, ulong[] messages){
		if(messages.length < 2 || messages.length > 100) return false;
		return requestResponse("channels/" ~ to!string(channel) ~ "/messages/bulk-delete", HTTPMethod.POST, Json(["messages": serializeToJson(messages)]), RouteType.Channel, channel);
	}

	//TODO editChannelPermissions

	//TODO getChannelInvites

	//TODO createChannelInvite

	//TODO deleteChannelPermission

	/**
	* Posts a typing indicator for several seconds (or until a message is sent) that is seen by clients, generally should not be implemented except for certain cases
	* Params:
	*	channel =	The `discord.types.Channel` to put the indicator in
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool triggerTypingIndicator(Channel channel){
		return triggerTypingIndicator(channel.id);
	}
	/// ditto
	public bool triggerTypingIndicator(ulong channel){
		return requestResponse("channels/" ~ to!string(channel) ~ "/typing", HTTPMethod.POST, Json.emptyObject, RouteType.Channel, channel);
	}
	/**
	* Gets a list of pinned messages in the channel
	* Params:
	*	channel =	The `discord.types.Channel` to get pinned messages from
	* Returns:
	*	An array of `discord.types.Message`s, can have a length of zero if no messages are pinned
	*/
	public Message[] getPinnedMessages(Channel channel){
		return getPinnedMessages(channel.id);
	}
	/// ditto
	public Message[] getPinnedMessages(ulong channel){
		Message[] messages;
		requestResponse("channels/" ~ to!string(channel) ~ "/pins", HTTPMethod.GET, Json.emptyObject, RouteType.Channel, channel, (scope res){
			if(res.statusCode != 200) return;
			messages = res.readJson().byValue().map!(m => Message(m)).array;
		});
		return messages;
	}
	/**
	* Adds a pinned message to the channel's list of pinned messages
	* Params:
	*	channel =	The `discord.types.Channel` to pin a `discord.types.Message` to
	*	message =	The `discord.types.Message` to pin
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool addPinnedMessage(Message message){
		return addPinnedMessage(message.channelId, message.id);
	}
	/// ditto
	public bool addPinnedMessage(Channel channel, ulong message){
		return addPinnedMessage(channel.id, message);
	}
	/// ditto
	public bool addPinnedMessage(ulong channel, ulong message){
		return requestResponse("channels/" ~ to!string(channel) ~ "/pins/" ~ to!string(message), HTTPMethod.PUT, Json.emptyObject, RouteType.Channel, channel);
	}
	/**
	* Removes a pinned message from the channel's list of pinned messages
	* Params:
	*	channel =	The `discord.types.Channel` to unpin a `discord.types.Message` from
	*	message =	The `discord.types.Message` to unpin
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deletePinnedMessage(Message message){
		return deletePinnedMessage(message.channelId, message.id);
	}
	/// ditto
	public bool deletePinnedMessage(Channel channel, ulong message){
		return deletePinnedMessage(channel.id, message);
	}
	/// ditto
	public bool deletePinnedMessage(ulong channel, ulong message){
		return requestResponse("channels/" ~ to!string(channel) ~ "/pins/" ~ to!string(message), HTTPMethod.DELETE, Json.emptyObject, RouteType.Channel, channel);
	}

	//TODO Group DM Add Recipient

	//TODO Group DM Remove Recipient
}