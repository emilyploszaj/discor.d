/**
* A subset of the Discord REST API function calls for emojis including methods to get emojis, create emojis, and delete emojis
*
* All methods are available in a `discord.bot.DiscordBot` instance and cannot be called from anywhere in `discord.rest.emoji`
* See_Also:
*	`discord.bot.DiscordBot`
* Authors:
*	Emily Rose Ploszaj
*/
module discord.rest.emoji;

import discord.bot;
import std.algorithm;
import std.conv;
import vibe.data.json;
import vibe.http.client;

/**
* The template mixin to deal with all REST requests delegated emojis requests, all methods are available in a `discord.bot.DiscordBot` instance
*/
mixin template RestEmoji(alias requestResponse){
	/**
	* Gets all emojis in a guild, probably shouldn't be used since all emoji information is already cached in the library, exists for completeness
	* Params:
	*	guild =		The `discord.types.Guild` to get `discord.types.Emoji`s from
	* Returns:
	*	An array of `discord.types.Emoji`s, can have a length of zero if no emojis exist
	*/
	public Emoji[] getAllEmojis(Guild guild){
		return getAllEmojis(guild.id);
	}
	/// ditto
	public Emoji[] getAllEmojis(ulong guild){
		Emoji[] emojis;
		requestResponse("guilds/" ~ to!string(guild) ~ "/emojis", HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			emojis = res.readJson().byValue().map!(e => parseTypeFromJson!Emoji(e)).array;
		});
		return emojis;
	}
	/**
	* Gets a single emoji from a guild, probably shouldn't be used since all emoji information is already cached in the library, exists for completeness
	* Params:
	*	guild =		The `discord.types.Guild` to get an `discord.types.Emoji` from
	*	emoji =		The id of the `discord.types.Emoji` to get
	*	The requested `discord.types.Emoji`
	*/
	public Emoji getEmoji(Guild guild, ulong emoji){
		return getEmoji(guild.id, emoji);
	}
	/// ditto
	public Emoji getEmoji(ulong guild, ulong emoji){
		Emoji result;
		requestResponse("guilds/" ~ to!string(guild) ~ "/emojis/" ~ to!string(emoji), HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			result = parseTypeFromJson!Emoji(res.readJson());
		});
		return result;
	}
	/**
	* Creates a new emoji in a guild
	* Params:
	*	guild =		The `discord.types.Guild` to create a new `discord.types.Emoji` in
	*	name =		The name of the new `discord.types.Emoji`
	*	data =		The base64 image data of the 128x128 image, must not be larger than 256kb
	*	roles =		The `discord.types.Role`s that are whitelisted to use this `discord.types.Emoji`
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool createEmoji(Guild guild, string name, string data){
		return createEmoji(guild.id, name, data);
	}
	/// ditto
	public bool createEmoji(ulong guild, string name, string data){
		if(data.length > 256000) return false; 
		return requestResponse("guilds/" ~ to!string(guild) ~ "/emojis", HTTPMethod.POST, Json(["name": Json(name), "image": Json(data)]), RouteType.Guild, guild);
	}
	/// ditto
	public bool createEmoji(Guild guild, string name, string data, Role[] roles){
		return createEmoji(guild.id, name, data, roles.map!(r => r.id).array);
	}
	/// ditto
	public bool createEmoji(Guild guild, string name, string data, ulong[] roles){
		return createEmoji(guild.id, name, data, roles);
	}
	/// ditto
	public bool createEmoji(ulong guild, string name, string data, Role[] roles){
		return createEmoji(guild, name, data, roles.map!(r => r.id).array);
	}
	/// ditto
	public bool createEmoji(ulong guild, string name, string data, ulong[] roles){
		if(data.length > 256000) return false; 
		return requestResponse("guilds/" ~ to!string(guild) ~ "/emojis", HTTPMethod.POST, Json(["name": Json(name), "image": Json(data), "roles": serializeToJson(roles)]), RouteType.Guild, guild);
	}
	/**
	* Modifies an emoji
	* Params:
	*	guild =		The `discord.types.Guild` to modify a `discord.types.Emoji` in
	*	emoji =		The `discord.types.Emoji` to modify
	*	name =		The name of the `discord.types.Emoji`
	*	roles =		The `discord.types.Role`s that are whitelisted to use this `discord.types.Emoji`
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyEmoji(Guild guild, Emoji emoji, string name){
		if(!emoji.custom) return false;
		return modifyEmoji(guild.id, emoji.id, name);
	}
	/// ditto
	public bool modifyEmoji(Guild guild, ulong emoji, string name){
		return modifyEmoji(guild.id, emoji, name);
	}
	/// ditto
	public bool modifyEmoji(ulong guild, Emoji emoji, string name){
		if(!emoji.custom) return false;
		return modifyEmoji(guild, emoji.id, name);
	}
	/// ditto
	public bool modifyEmoji(ulong guild, ulong emoji, string name){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/emojis/" ~ to!string(emoji), HTTPMethod.PATCH, Json(["name": Json(name)]), RouteType.Guild, guild);
	}
	/// ditto
	public bool modifyEmoji(Guild guild, Emoji emoji, string name, Role[] roles){
		if(!emoji.custom) return false;
		return modifyEmoji(guild.id, emoji.id, name, roles.map!(r => r.id).array);
	}
	/// ditto
	public bool modifyEmoji(Guild guild, Emoji emoji, string name, ulong[] roles){
		if(!emoji.custom) return false;
		return modifyEmoji(guild.id, emoji.id, name, roles);
	}
	/// ditto
	public bool modifyEmoji(Guild guild, ulong emoji, string name, Role[] roles){
		return modifyEmoji(guild.id, emoji, name, roles.map!(r => r.id).array);
	}
	/// ditto
	public bool modifyEmoji(Guild guild, ulong emoji, string name, ulong[] roles){
		return modifyEmoji(guild.id, emoji, name, roles);
	}
	/// ditto
	public bool modifyEmoji(ulong guild, Emoji emoji, string name, Role[] roles){
		if(!emoji.custom) return false;
		return modifyEmoji(guild, emoji.id, name, roles.map!(r => r.id).array);//Okay this is absurd who will ever use this mix of variables
	}
	/// ditto
	public bool modifyEmoji(ulong guild, Emoji emoji, string name, ulong[] roles){
		if(!emoji.custom) return false;
		return modifyEmoji(guild, emoji.id, name, roles);
	}
	/// ditto
	public bool modifyEmoji(ulong guild, ulong emoji, string name, Role[] roles){
		return modifyEmoji(guild, emoji, name, roles.map!(r => r.id).array);
	}
	/// ditto
	public bool modifyEmoji(ulong guild, ulong emoji, string name, ulong[] roles){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/emojis/" ~ to!string(emoji), HTTPMethod.PATCH, Json(["name": Json(name), "roles": serializeToJson(roles)]), RouteType.Guild, guild);
	}
	/**
	* Deletes an emoji
	* Params:
	*	guild =		The `discord.types.Guild` to delete the `discord.types.Emoji` from
	*	emoji =		The `discord.types.Emoji` to delete
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteEmoji(Guild guild, Emoji emoji){
		return deleteEmoji(guild.id, emoji.id);
	}
	/// ditto
	public bool deleteEmoji(Guild guild, ulong emoji){
		return deleteEmoji(guild.id, emoji);
	}
	/// ditto
	public bool deleteEmoji(ulong guild, Emoji emoji){
		return deleteEmoji(guild, emoji.id);
	}
	/// ditto
	public bool deleteEmoji(ulong guild, ulong emoji){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/emojis/" ~ to!string(emoji), HTTPMethod.DELETE, Json.emptyObject, RouteType.Guild, guild);
	}
}