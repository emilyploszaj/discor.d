import discord.bot;
import discord.types;
import std.algorithm;
import std.conv;
import std.random;
import std.stdio;
import std.string;
import std.uni;

DiscordBot bot;

void main(){
	//Replace this file with a file containing your oath token
	File f = File("../../../discord.token");
	string oathToken = f.readln().strip();

	//Create a child class to DiscordEvents and make an instance
	Events events = new Events();
	
	//Pass your token and a DiscordEvents instance
	bot = new DiscordBot(oathToken, events);
	//Start the bot
	bot.start();
}
//Class used to get all events from discor.d
class Events: DiscordEvents{
	//Override the method for message creation, many other events exist, see documentation for discord.bot.DiscordEvents
	public override void messageCreate(Message m){
		if(m.content == "ping"){
			bot.sendMessage(m.channel, "pong");
		}
	}
}