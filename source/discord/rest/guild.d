/**
* A subset of the Discord REST API function calls for guilds including methods to interact with guilds, roles, permissions, and guild members
*
* All methods are available in a `discord.bot.DiscordBot` instance and cannot be called from anywhere in `discord.rest.guild`
* See_Also:
*	`discord.bot.DiscordBot`
* Authors:
*	Emily Rose Ploszaj
*/
module discord.rest.guild;

import discord.bot;
import std.conv;
import std.uri;
import vibe.data.json;
import vibe.http.client;

/**
* The template mixin to deal with all REST requests delegated guild requests, all methods are available in a `discord.bot.DiscordBot` instance
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
*		ulong coolRoleId = 555382244765463966;
*
*		//Give the Cool Role to anyone who says "cool"
*		//It's assumed that this bot is only in one guild
*		if(m.content == "cool"){
*			bot.addGuildMemberRole(guild, m.author.id, coolRoleId);
*		}
*
*		import std.algorithm.searching: countUntil;
*
*		//Remove the Cool Role to anyone who says "not cool" who's currently in Cool Role
*		//It's assumed that this bot is only in one guild
*		if(m.content == "not cool"){
*			//Check to see if this author has the Cool Role
*			if(guild.members.countUntil!(member => member.user.id == m.author.id && member.roles.countUntil(coolRoleId) != -1) != -1){
*				bot.removeGuildMemberRole(guild, m.author.id, coolRoleId);
*			}
*		}
*	}
*	---
*/
mixin template RestGuild(alias requestResponse){

	//TODO createGuild

	//TODO getGuild, implemented with cache

	//TODO fix this
	public bool modifyGuildRole(ulong guildId, ulong roleId, Role role){
		Json json = Json(["name": Json(role.name),
			"permissions": Json(role.permissions.permissions),
			"color": Json(role.color),
			"hoist": Json(role.hoist),
			"mentionable": Json(role.mentionable)]);
		return requestResponse("guilds/" ~ to!string(guildId) ~ "/roles/" ~ to!string(roleId), HTTPMethod.PATCH, json, RouteType.Guild, guildId);
	}
	/**
	* Permanently deletes a guild, must be owner to use action
	* Params:
	*	guild =		The `discord.types.Guild` to delete
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteGuild(Guild guild){
		return deleteGuild(guild.id);
	}
	/// ditto
	public bool deleteGuild(ulong guild){
		return requestResponse("guilds/" ~ to!string(guild), HTTPMethod.DELETE, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Gets a list of channels in a guild
	* Params:
	*	guild =		The `discord.types.Guild` to get `discord.types.Channel`s from
	* Returns:
	*	An array of `discord.types.Channel`s
	*/
	public Guild[] getGuildChannels(Guild guild){
		return getGuildChannels(guild.id);
	}
	/// ditto
	public Guild[] getGuildChannels(ulong guild){
		Guild[] guilds;
		requestResponse("guilds/" ~ to!string(guild) ~ "/channels", HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			guilds = res.readJson().byValue().map!(g => Guild(g)).array;
		});
		return guilds;
	}

	//TODO createGuildChannel

	/**
	* Modifies the positions of channels in the sidebar list
	* Params:
	*	guild =		The `discord.types.Guild` to modify `discord.types.Channel` order in
	*	channels =	A `discord.types.Channel`[position] structured associative array designating new positions
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyChannelPositions(Channel[uint] channels){
		if(channels.length == 0) return false;
		ulong[uint] newChannels;
		foreach(c; channels.byKeyValue()){
			newChannels[c.key] = c.value.id;
		}
		return modifyChannelPositions(channels.values[0].guildId, newChannels);
	}
	/// ditto
	public bool modifyChannelPositions(Guild guild, ulong[uint] channels){
		return modifyChannelPositions(guild.id, channels);
	}
	/// ditto
	public bool modifyChannelPositions(ulong guild, ulong[uint] channels){
		Json json = Json.emptyArray;
		foreach(c; channels.byKeyValue()){
			json ~= Json(["id": Json(c.value), "position": Json(c.key)]);
		}
		return requestResponse("guilds/" ~ to!string(guild) ~ "/channels", HTTPMethod.PATCH, json, RouteType.Guild, guild);
	}
	/**
	* Gets a guild member from a guild
	* Params:
	*	guild =		The `discord.types.Guild` the `discord.types.GuildMember` is in
	*	member =	The id of the `discord.types.GuildMember`
	* Returns:
	*	The `discord.types.GuildMember` specified
	*/
	public GuildMember getGuildMember(Guild guild, ulong member){
		return getGuildMember(guild.id, member);
	}
	/// ditto
	public GuildMember getGuildMember(ulong guild, ulong member){
		GuildMember result;
		requestResponse("guilds/" ~ to!string(guild) ~ "/members/" ~ to!string(member), HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			result = parseTypeFromJson!GuildMember(res.readJson());
		});
		return result;
	}
	/**
	* Gets a list of guild members from a guild, supports pagination
	* Params:
	*	guild =		The `discord.types.Guild` to get `discord.types.GuildMember`s from
	*	limit =		Optional, the [1-1000] limit of `discord.types.GuildMember`s to return
	*	after =		Optional, the `discord.types.GuildMember` with the highest id from the previous page, for pagination
	* Returns:
	*	An array of length [0-limit] `discord.types.GuildMember`s
	*/
	public GuildMember[] listGuildMembers(Guild guild, int limit, GuildMember after){
		return listGuildMembers(guild.id, limit, after.user.id);
	}
	/// ditto
	public GuildMember[] listGuildMembers(Guild guild, int limit = 1000, ulong after = 0){
		return listGuildMembers(guild.id, limit, after);
	}
	/// ditto
	public GuildMember[] listGuildMembers(ulong guild, int limit, GuildMember after){
		return listGuildMembers(guild, limit, after.user.id);
	}
	/// ditto
	public GuildMember[] listGuildMembers(ulong guild, int limit = 1000, ulong after = 0){
		GuildMember[] members;
		if(limit < 1 || limit > 1000) return members;
		string url = "guilds/" ~ to!string(guild) ~ "/members?limit=" ~ to!string(limit);
		if(after != 0) url ~= "&after=" ~ to!string(after);
		requestResponse(url, HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild);
		return members;
	}

	//TODO addGuildMember requires oauth2 token for users, not in scope of bot activities

	/**
	* Modifies a guild member using local changes
	* Params:
	*	guild =		The `discord.types.Guild` the `discord.types.GuildMember` is in
	*	member =	The `discord.types.GuildMember` to modify, with changes applied
	*	channel =	Optional, the voice `discord.types.Channel` to move user to, or zero to remove them from their current one
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyGuildMember(GuildMember member, Channel channel){
		return modifyGuildMember(channel.guildId, member, channel.id);
	}
	/// ditto
	public bool modifyGuildMember(Guild guild, GuildMember member, ulong channel){
		return modifyGuildMember(guild.id, member, channel);
	}
	/// ditto
	public bool modifyGuildMember(ulong guild, GuildMember member, ulong channel){
		Json json = Json([
			"nick": Json(member.nick),
			"roles": serializeToJson(member.roleIds),
			"mute": Json(member.mute),
			"deaf": Json(member.deaf)
		]);
		if(channel == 0) json["channel_id"] = Json(null);
		else json["channel_id"] = Json(channel);
		return requestResponse("guilds/" ~ to!string(guild) ~ "/members/" ~ to!string(member.user.id), HTTPMethod.PATCH, json, RouteType.Guild, guild);
	}
	/// ditto
	public bool modifyGuildMember(Guild guild, GuildMember member){
		return modifyGuildMember(guild.id, member);
	}
	/// ditto
	public bool modifyGuildMember(ulong guild, GuildMember member){
		Json json = Json([
			"nick": Json(member.nick),
			"roles": serializeToJson(member.roleIds),
			"mute": Json(member.mute),
			"deaf": Json(member.deaf)
		]);
		return requestResponse("guilds/" ~ to!string(guild) ~ "/members/" ~ to!string(member.user.id), HTTPMethod.PATCH, json, RouteType.Guild, guild);
	}
	/**
	* Modifies the current bot user's nickname in a guild
	* Params:
	*	guild =		The `discord.types.Guild` to modify nickname in
	*	nick =		The new nickname
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyCurrentUserNick(Guild guild, string nick){
		return modifyCurrentUserNick(guild.id, nick);
	}
	/// ditto
	public bool modifyCurrentUserNick(ulong guild, string nick){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/members/@me/nick", HTTPMethod.PATCH, Json(["nick": Json(nick)]), RouteType.Guild, guild);
	}
	/**
	* Adds a role to a guild member
	* Params:
	*	guild =		The `discord.types.Guild` to modify in
	*	member =	The `discord.types.GuildMember` to add a `discord.types.Role` to
	*	role =		The `discord.types.Role` to add
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool addGuildMemberRole(Guild guild, GuildMember member, Role role){
		return addGuildMemberRole(guild.id, member.user.id, role.id);
	}
	/// ditto
	public bool addGuildMemberRole(Guild guild, GuildMember member, ulong role){
		return addGuildMemberRole(guild.id, member.user.id, role);
	}
	/// ditto
	public bool addGuildMemberRole(Guild guild, ulong member, Role role){
		return addGuildMemberRole(guild.id, member, role.id);
	}
	/// ditto
	public bool addGuildMemberRole(Guild guild, ulong member, ulong role){
		return addGuildMemberRole(guild.id, member, role);
	}
	/// ditto
	public bool addGuildMemberRole(ulong guild, GuildMember member, Role role){
		return addGuildMemberRole(guild, member.user.id, role.id);
	}
	/// ditto
	public bool addGuildMemberRole(ulong guild, GuildMember member, ulong role){
		return addGuildMemberRole(guild, member.user.id, role);
	}
	/// ditto
	public bool addGuildMemberRole(ulong guild, ulong member, Role role){
		return addGuildMemberRole(guild, member, role.id);
	}
	/// ditto
	public bool addGuildMemberRole(ulong guild, ulong member, ulong role){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/members/" ~ to!string(member) ~ "/roles/" ~ to!string(role), HTTPMethod.PUT, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Removes a role from a guild member
	* Params:
	*	guild =		The `discord.types.Guild` to modify in
	*	member =	The `discord.types.GuildMember` to remove a `discord.types.Role` from
	*	role =		The `discord.types.Role` to remove
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool removeGuildMemberRole(Guild guild, GuildMember member, Role role){
		return removeGuildMemberRole(guild.id, member.user.id, role.id);
	}
	/// ditto
	public bool removeGuildMemberRole(Guild guild, GuildMember member, ulong role){
		return removeGuildMemberRole(guild.id, member.user.id, role);
	}
	/// ditto
	public bool removeGuildMemberRole(Guild guild, ulong member, Role role){
		return removeGuildMemberRole(guild.id, member, role.id);
	}
	/// ditto
	public bool removeGuildMemberRole(Guild guild, ulong member, ulong role){
		return removeGuildMemberRole(guild.id, member, role);
	}
	/// ditto
	public bool removeGuildMemberRole(ulong guild, GuildMember member, Role role){
		return removeGuildMemberRole(guild, member.user.id, role.id);
	}
	/// ditto
	public bool removeGuildMemberRole(ulong guild, GuildMember member, ulong role){
		return removeGuildMemberRole(guild, member.user.id, role);
	}
	/// ditto
	public bool removeGuildMemberRole(ulong guild, ulong member, Role role){
		return removeGuildMemberRole(guild, member, role.id);
	}
	/// ditto
	public bool removeGuildMemberRole(ulong guild, ulong member, ulong role){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/members/" ~ to!string(member) ~ "/roles/" ~ to!string(role), HTTPMethod.DELETE, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Kicks a member from a guild
	* Params:
	*	guild =		The `discord.types.Guild` to kick from
	*	member =	The `discord.types.GuildMember` to kick
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool removeGuildMember(Guild guild, GuildMember member){
		return removeGuildMember(guild.id, member.user.id);
	}
	/// ditto
	public bool removeGuildMember(Guild guild, ulong member){
		return removeGuildMember(guild.id, member);
	}
	/// ditto
	public bool removeGuildMember(ulong guild, GuildMember member){
		return removeGuildMember(guild, member.user.id);
	}
	/// ditto
	public bool removeGuildMember(ulong guild, ulong member){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/member/" ~ to!string(member), HTTPMethod.DELETE, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Gets a list of bans in the guild
	* Params:
	*	guild =		The `discord.types.Guild` to get `discord.types.Ban`s from
	* Returns:
	*	An array of `discord.types.Ban`s
	*/
	public Ban[] getGuildBans(Guild guild){
		return getGuildBans(guild.id);
	}
	/// ditto
	public Ban[] getGuildBans(ulong guild){
		Ban[] bans;
		requestResponse("guilds/" ~ to!string(guild) ~ "/bans", HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			bans = res.readJson().byValue().map!(b => b.parseTypeFromJson!Ban).array;
		});
		return bans;
	}
	/**
	* Gets a ban of a specific user
	* Params:
	*	guild =		The `discord.types.Guild` to get a `discord.types.Ban` from
	*	user =		The `discord.types.User` to get the `discord.types.Ban` of
	* Returns:
	*	A `discord.types.Ban` for the supplied `discord.types.User` or an empty `discord.types.Ban` object if one doesn't exist
	*/
	public Ban getGuildBan(Guild guild, User user){
		return getGuildBan(guild.id, user.id);
	}
	/// ditto
	public Ban getGuildBan(Guild guild, ulong user){
		return getGuildBan(guild.id, user);
	}
	/// ditto
	public Ban getGuildBan(ulong guild, User user){
		return getGuildBan(guild, user.id);
	}
	/// ditto
	public Ban getGuildBan(ulong guild, ulong user){
		Ban ban;
		requestResponse("guilds/" ~ to!string(guild) ~ "/bans/" ~ to!string(user), HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			ban = res.readJson().parseTypeFromJson!Ban;
		});
		return ban;
	}
	/**
	* Bans a user from a guild
	* Params:
	*	guild =		The `discord.types.Guild` to create the `discord.types.Ban` in
	*	member =	The `discord.types.GuildMember` to ban
	*	deleteMessageDays =	Optional, the amount of days [0-7] back to delete messages from this user
	*	reason =	Optional, the reason the ban was done
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool createGuildBan(Guild guild, GuildMember member, int deleteMessageDays = -1, string reason = ""){
		return createGuildBan(guild.id, member.user.id, deleteMessageDays, reason);
	}
	/// ditto
	public bool createGuildBan(Guild guild, ulong member, int deleteMessageDays = -1, string reason = ""){
		return createGuildBan(guild.id, member, deleteMessageDays, reason);
	}
	/// ditto
	public bool createGuildBan(ulong guild, GuildMember member, int deleteMessageDays = -1, string reason = ""){
		return createGuildBan(guild, member.user.id, deleteMessageDays, reason);
	}
	/// ditto
	public bool createGuildBan(ulong guild, ulong member, int deleteMessageDays = -1, string reason = ""){
		if(deleteMessageDays > 7) return false;
		string url = "guilds/" ~ to!string(guild) ~ "/bans/" ~ to!string(member);
		if(deleteMessageDays >= 0){
			url ~= "?delete-message-days=" ~ to!string(deleteMessageDays);
			if(reason != "") url ~= "&reason=" ~ reason.encodeComponent;
		}else if(reason != "") url ~= "?reason=" ~ reason.encodeComponent;
		return requestResponse(url, HTTPMethod.PUT, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Removes a ban from a user
	* Params:
	*	guild =		The `discord.types.Guild` to remove the `discord.types.Ban` from
	*	user =		The `discord.types.User` to unban
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool removeGuildBan(Guild guild, User user){
		return removeGuildBan(guild.id, user.id);
	}
	/// ditto
	public bool removeGuildBan(Guild guild, ulong user){
		return removeGuildBan(guild.id, user);
	}
	/// ditto
	public bool removeGuildBan(ulong guild, User user){
		return removeGuildBan(guild, user.id);
	}
	/// ditto
	public bool removeGuildBan(ulong guild, ulong user){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/bans/" ~ to!string(user), HTTPMethod.DELETE, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Gets a list of roles from a guild
	* Params:
	*	guild =		The `discord.types.Guild` to get `discord.types.Role`s from
	* Returns:
	*	An array of `discord.types.Role`s
	*/
	public Role[] getGuildRoles(Guild guild){
		return getGuildRoles(guild.id);
	}
	/// ditto
	public Role[] getGuildRoles(ulong guild){
		Role[] roles;
		requestResponse("guilds/" ~ to!string(guild) ~ "/roles", HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			roles = res.readJson().byValue().map!(r => parseTypeFromJson!Role(r)).array;
		});
		return roles;
	}
	/**
	* Creates a new role in a guild
	* Params:
	*	guild =		The `discord.types.Guild` to create a new `discord.types.Role` in
	*	name =		The name of the new `discord.types.Role`
	*	permissions =	Optional, the set of `discord.types.Permissions` assigned to this `discord.types.Role`, if not passed, inherets from @everyone
	*	color =		Optional, the 24 bit color code of the new `discord.types.Role` where 0x000000 is inheret color
	*	hoist =		Optional, whether to display this `discord.types.Role` in its own separate category on the sidebar
	*	mentionable =	Optional, whether users can mention this `discord.types.Role`
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool createGuildRole(Guild guild, string name, int color = 0, bool hoist = false, bool mentionable = false){
		return createGuildRole(guild.id, name, color, hoist, mentionable);
	}
	/// ditto
	public bool createGuildRole(ulong guild, string name, int color = 0, bool hoist = false, bool mentionable = false){
		Json json = Json([
			"name": Json(name),
			"color": Json(color),
			"hoist": Json(hoist),
			"mentionable": Json(mentionable)
		]);
		return requestResponse("guilds/" ~ to!string(guild) ~ "/roles", HTTPMethod.POST, json, RouteType.Guild, guild);
	}
	/// ditto
	public bool createGuildRole(Guild guild, string name, Permissions permissions, int color = 0, bool hoist = false, bool mentionable = false){
		return createGuildRole(guild.id, name, permissions, color, hoist, mentionable);
	}
	/// ditto
	public bool createGuildRole(ulong guild, string name, Permissions permissions, int color = 0, bool hoist = false, bool mentionable = false){
		Json json = Json([
			"name": Json(name),
			"permissions": Json(permissions.permissions),
			"color": Json(color),
			"hoist": Json(hoist),
			"mentionable": Json(mentionable)
		]);
		return requestResponse("guilds/" ~ to!string(guild) ~ "/roles", HTTPMethod.POST, json, RouteType.Guild, guild);
	}
	/**
	* Modifies the positions of roles in the role list
	* Params:
	*	guild =		The `discord.types.Guild` to change `discord.types.Role` order in
	*	roles =		A `discord.types.Role`[position] structured associative array designating new positions
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyGuildRolePositions(Guild guild, Role[uint] roles){
		if(roles.length == 0) return false;
		ulong[uint] newRoles;
		foreach(r; roles.byKeyValue){
			newRoles[r.key] = r.value.id;
		}
		return modifyGuildRolePositions(guild.id, newRoles);
	}
	/// ditto
	public bool modifyGuildRolePositions(Guild guild, ulong[uint] roles){
		return modifyGuildRolePositions(guild.id, roles);
	}
	/// ditto
	public bool modifyGuildRolePositions(ulong guild, Role[uint] roles){
		if(roles.length == 0) return false;
		ulong[uint] newRoles;
		foreach(r; roles.byKeyValue){
			newRoles[r.key] = r.value.id;
		}
		return modifyGuildRolePositions(guild, newRoles);
	}
	/// ditto
	public bool modifyGuildRolePositions(ulong guild, ulong[uint] roles){
		Json json = Json.emptyArray;
		foreach(r; roles.byKeyValue()){
			json ~= Json(["id": Json(r.value), "position": Json(r.key)]);
		}
		return requestResponse("guilds/" ~ to!string(guild) ~ "/roles", HTTPMethod.PATCH, json, RouteType.Guild, guild);
	}
	/**
	* Modifies a guild role using local changes
	* Params:
	*	guild =		The `discord.types.Guild` to modify a `discord.types.Role` in
	*	role =		The `discord.types.Role` with modifications
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool modifyGuildRole(Guild guild, Role role){
		return modifyGuildRole(guild.id, role);
	}
	/// ditto
	public bool modifyGuildRole(ulong guild, Role role){
		Json json = Json([
			"name": Json(role.name),
			"permissions": Json(role.permissions.permissions),
			"color": Json(role.color),
			"hoist": Json(role.hoist),
			"mentionable": Json(role.mentionable)
		]);
		return requestResponse("guilds/" ~ to!string(guild) ~ "/roles/" ~ to!string(role.id), HTTPMethod.PATCH, json, RouteType.Guild, guild);
	}
	/**
	* Deletes a guild role
	* Params:
	*	guild =		The `discord.types.Guild` to delete a `discord.types.Role` from
	*	role =		The `discord.types.Role` to delete
	* Returns:
	*	`true` if successful, `false` otherwise
	*/
	public bool deleteGuildRole(Guild guild, Role role){
		return deleteGuildRole(guild.id, role.id);
	}
	/// ditto
	public bool deleteGuildRole(Guild guild, ulong role){
		return deleteGuildRole(guild.id, role);
	}
	/// ditto
	public bool deleteGuildRole(ulong guild, Role role){
		return deleteGuildRole(guild, role.id);
	}
	/// ditto
	public bool deleteGuildRole(ulong guild, ulong role){
		return requestResponse("guilds/" ~ to!string(guild) ~ "/roles/" ~ to!string(role), HTTPMethod.DELETE, Json.emptyObject, RouteType.Guild, guild);
	}
	/**
	* Gets the number of users that would be removed in a prune operation
	* Params:
	*	guild =		The `discord.types.Guild` to check
	*	days =		The number of days (minimum 1) to use to check
	* Returns:
	*	The number of members that would be pruned or -1 if operation fails
	*/
	public int getGuildPruneCount(Guild guild, uint days){
		return getGuildPruneCount(guild.id, days);
	}
	/// ditto
	public int getGuildPruneCount(ulong guild, uint days){
		int pruned = -1;
		if(days < 1) return pruned;
		requestResponse("guilds/" ~ to!string(guild) ~ "/prune?days=" ~ to!string(days), HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			pruned = res.readJson()["pruned"].get!int;
		});
		return pruned;
	}
	/**
	* Begins a guild prune
	* Params:
	*	guild =		The `discord.types.Guild` to prune
	*	days =		The amount of days (minimum 1) used to prune
	*	computePruneCount =	Optional, whether the amount of pruned members should be computed
	* Returns:
	*	The number of members that were pruned or -1 if operation fails (will return 0 on success if `computePruneCount` is `false`)
	*/
	public int beginGuildPrune(Guild guild, uint days, bool computePruneCount = true){
		return beginGuildPrune(guild.id, days);
	}
	/// ditto
	public int beginGuildPrune(ulong guild, uint days, bool computePruneCount = true){
		int pruned = -1;
		if(days < 1) return pruned;
		requestResponse("guilds/" ~ to!string(guild) ~ "/prune?days=" ~ to!string(days) ~ "&compute_prune_count=" ~ to!string(computePruneCount), HTTPMethod.POST, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			if(computePruneCount == false) pruned = 0;
			else pruned = res.readJson()["pruned"].get!int;
		});
		return pruned;
	}
	
	//TODO getGuildVoiceRegions

	//TODO getGuildInvites

	//TODO getGuildIntegrations, createGuildIntegration, modifyGuildIntegration, deleteGuildIntegreation, syncGuildIntegration, might not be in scope of application

	//TODO getGuildEmbed, modifyGuildEmbed, might not be in scope of application

	/**
	* Gets the partitial vanity invite code for the guild
	* Params:
	*	guild =		The `discord.types.Guild` to get the vanity url from
	* Returns:
	*	The vanity url for this `discord.types.Guild` or a blank string if one does not exist
	*/
	public string getGuildVanityURL(Guild guild){
		return getGuildVanityURL(guild.id);
	}
	/// ditto
	public string getGuildVanityURL(ulong guild){
		string url;
		requestResponse("guilds/" ~ to!string(guild) ~ "/vanity-url", HTTPMethod.GET, Json.emptyObject, RouteType.Guild, guild, (scope res){
			if(res.statusCode != 200) return;
			Json json = res.readJson();
			if(json["code"].type != Json.Type.string) return;
			url = json["code"].get!string;
		});
		return url;
	}

	//TODO getGuildWidgetImage
}