import discord.bot;
import discord.types;
import std.algorithm;
import std.array;
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
    public override void guildCreate(Guild guild){
        Channel[] channels = guild.channels;
        //Pick out categories and put them in order
        Channel[] categories = channels.filter!(c => c.type == Channel.Type.GuildCategory).array
            .sort!((a, b) => a.position < b.position).array;
        
        writeln(guild.name);

        //Peach, Jigglypuff, etc.
        Channel[] floaties = channels.filter!(c => c.parentId == 0).array
            .sort!((a, b) => a.position < b.position).array;

        //Construct an array of lines to be printed
        string[] outer = floaties.filter!(c => c.type == Channel.Type.GuildText).array
            .sort!((a, b) => a.position < b.position)
            .map!(c => "├#️⃣ " ~ c.name).array;
        outer ~= floaties.filter!(c => c.type == Channel.Type.GuildVoice).array
            .sort!((a, b) => a.position < b.position)
            .map!(c => "├🔊 " ~ c.name).array;

        //For if there are no categories
        if(categories.length == 0){
            outer[$ - 1] = "└" ~ outer[$ - 1][3..$];
        }

        outer.each!writeln;

        //Loop through categories
        for(int i = 0; i < categories.length; i++){
            Channel cat = categories[i];

            //Deal with drawing the file connections
            string sep = "│";
            if(i + 1 < categories.length) write("├");
            else{
                write("└");
                sep = " ";
            }

            //Write the category name as an insert (either next to a ├ or a └ character)
            writeln("─▼ " ~ cat.name);

            //Grab all channels in this category
            Channel[] sub = channels.filter!(c => c.parentId == cat.id).array;

            //Construct an array of lines to be printed
            string[] inner = sub.filter!(c => c.type == Channel.Type.GuildText).array
                .sort!((a, b) => a.position < b.position)
                .map!(c => sep ~ " ├#️⃣ " ~ c.name).array;
            inner ~= sub.filter!(c => c.type == Channel.Type.GuildVoice).array
                .sort!((a, b) => a.position < b.position)
                .map!(c => sep ~ " ├🔊 " ~ c.name).array;
            
            //Change the insert character of the last lines
            if(inner.length > 0){
                //These are funky gross lines, box drawing characters are actually several characters
                if(i + 1 < categories.length) inner[$ - 1] = "| └" ~ inner[$ - 1][7..$];
                else inner[$ - 1] = "  └" ~ inner[$ - 1][5..$];
            }

            inner.each!writeln;
        }
    }
}