COLORS = { 			none: "\033[0m",
								black: "\033[0;30m",
								red: "\033[0;31m",
								green: "\033[0;32m",
								brown: "\033[0;33m",
								blue: "\033[0;34m",
								purple: "\033[0;35m",
								cyan: "\033[0;36m",
								lightgray: "\033[0;37m",
								darkgray: "\033[1;30m",
								lightred: "\033[1;31m",
								lightgreen: "\033[1;32m",
								yellow: "\033[1;33m",
								lightblue: "\033[1;34m",
								lightpurple: "\033[1;35m",
								lightcyan: "\033[1;36m",
								white: "\033[1;37m" }

class World
	@@entity_list = []
	def initialize(world_list, npc_types = nil)
		@@world_list = world_list
		@@entity_list = []
		@@npc_types = npc_types
		@@world_list.each do |room| # Replace strings with actual NPC clones
			newmobs = []
			room.mobs.each do |mob|
				newmob = @@npc_types[mob].clone
				newmob.location = room
				newmobs << newmob
			end
			room.mobs = newmobs
		end
	end
	def self.find(thing) # find a location
		if thing.class == Entity
      ent_idx = @@entity_list.find_index { |x| x.mobs.include(thing) }
      return @@world_list[ent_idx]
    elsif thing.class == String
      loc_idx = @@world_list.find_index { |x| x.name.downcase.strip == thing.downcase.strip }
    	return @@world_list[loc_idx]
    end
  end
  def self.start_combat_tick # World updater
  	loop do # Yes, it's an infinite loop
  	  sleep(1.5)
  	  #puts "TICK!"
  	  @@entity_list.each do |ent|
  	  	if !ent.is_a? Entity
  	  		next
  	  	end
  	  	#puts "Entity #{ent.name} #{ent.hp} hp"
  	  	if (ent.fighting)
  	  		ent.attack(ent.fighting)
  	  	end
  	  	if (ent.hp <= 0)
  	  		ent.die
  	  	end
  	  end
  	end
  end
  def self.start_heal_tick
  	loop do
  		sleep(20)
  	  @@entity_list.each do |ent|
  	  	if !ent.is_a? Entity
  	  		next
  	  	end
  	  	if (ent.hp <= ent.max_hp)
  	  		ent.heal(ent.max_hp / 40)
  	  	end
  	  end
  	end
  end
  def self.add_entity(ent)
  	@@entity_list << ent
  end
  def self.delete_entity(ent)
		newlist = @@entity_list.reject{ |x| x == ent }
		@@entity_list = newlist
  end
end

class Location
	attr_reader :description, :exits, :name
	attr_accessor :mobs

	def initialize(name, desc, mobs, exits, special = nil)
		@name = name
		@description = desc
		@mobs = mobs
		@exits = exits
		@special = special
	end
	def describe(player = p)
		  say(@name)
			say(@description)
			say("[" + @exits.map{ |exit| exit.first }.join(", ") + "]")
			@mobs.each do |mob|
				say(" " + mob.name + " is here.")
			end
	end
	def find(criteria)
		@mobs.each do |mob|
			if (mob.name.downcase.strip.index(criteria.downcase.strip))
				return mob
			end
			return nil
		end
	end
end

class Entity
	attr_reader :name, :hp, :level, :weapon, :hp, :max_hp
	attr_accessor :location, :fighting
	def initialize(name, hp, level, weapon, location)
		@name = name
		@hp = hp
		@max_hp = hp
		@level = level
		@weapon = weapon
		@location = location
		@fighting = nil
		World.add_entity self
	end
	def damage(amount)
		@hp -= amount
		if @hp <= 0
			return true
		end
	end
	def heal(amount)
		@hp += amount
		if @hp > @max_hp
			@hp = @max_hp
		end
	end
	def die
		# puts "DEBUG: #{@name} dying. Entity."
		#cease combat
		if (@fighting)
			@fighting.fighting = nil
		  @fighting = nil
		end
		#remove from location
		newmobs = @location.mobs.reject{ |x| x == self }
		@location.mobs = newmobs

	end
	def attack(ent)
		if @hp <= 0
			return
		end
		@fighting = ent
		ent.fighting = self
		r = Random.new
		damage = (1..6).rand * @level
		ent.damage(damage)
	end
	def place(loc_name)
		new_loc = World.find(loc_name)
		unless new_loc.nil?
		  @location = new_loc
		end
	end
end

class NPC < Entity
	attr_reader :aggro
  def initialize(name, hp, level, weapon, location, aggro)
  	super(name, hp, level, weapon, location)
  	@aggro = aggro
  end
  def clone
  	return NPC.new(@name, @hp, @level, @weapon, @location, @aggro)
  end
  def die
		#puts "DEBUG: #{@name} dying. NPC."
  	super
  	say("#{COLORS[:red]}#{@name} has died!#{COLORS[:none]}")
  	World.delete_entity(self)
  	@location = nil
  end
  def attack
  	super
  	say("#{COLORS[:lightred]}#{@name} deals #{damage} to you with their #{weapon}!#{COLORS[:none]}")
  end
end

class Player < Entity
	attr_reader :experience, :max_experience
  def initialize(name, hp, level, weapon, location)
  	super(name, hp, level, weapon, location)
  	@experience = 0
  	@max_experience = 100
  end
  def move(location)
  	if (@fighting)
  		say("You cannot leave now, you are in a fight with #{@fighting.name}!")
  		return
  	end
  	place(location)
  	@location.describe
  	@location.mobs.each do |mob|
  		if mob.aggro == true
  		  mob.attack(self)
  		end
  	end
  end
  def die
		# puts "DEBUG: #{@name} dying. Player."
  	super
  	say("#{COLORS[:red]}YOU HAVE DIED!#{COLORS[:none]}")
  	@hp = @max_hp
  	@experience = 0
    move("The void")
  end
  def attack(ent)
  	super
  	say("#{COLORS[:lightgreen]}You deal #{damage} to #{ent.name} with your #{weapon}!#{COLORS[:none]}")
  	if (ent.hp <= 0)
			xp = ((ent.level - @level + 1)  ** 2) * 10
			@experience += xp
			say("#{COLORS[:cyan]}You gain #{xp} experience!#{COLORS[:none]}")
		end
	end
	def level_up
		@level += 1
		@experience = @experience - @max_experience
		say("#{COLORS[:green]}Congrats! You have achieved LEVEL #{@level}#{COLORS[:none]}")
		@max_experience = (@max_experience * 1.1).floor
	end
end

class Item
	attr_reader :name, :description, :actions
	def initialize(name, desc, actions=nil)
		@name = name
		@description = description
		@actions = actions
  end
  def show
  	say @description
  end
end

def say(text, speaker=nil)
	if speaker
		print speaker + " says: "
	end
	puts text
end

world = World.new([
	Location.new("The void", "You did something to break the game! Your punishment is being stuck in this gray, nameless space.", [], [["leave", "The Front Yard"]]),
	Location.new("The Front Yard", "There is a haunted mansion in front of you.
 The cast iron gate separates the driveway from the road.
  The windows are mostly broken and covered in cobwebs,
   and there is a dreary willow tree out front. Do you dare go in?", [], [["enter", "The Foyer"], ["run away", :quit]]),
Location.new("The Foyer", "You are in the foyer. A dusty china cabinet is to the right, and
	to the left is a bunch of missing floorboard, just about big enough to fit through. There is a grand staircase going up to the mezzanine. North is
	another antechamber room. South is the exit through the front door.", [],
	 [["north", "The Antechamber"],
	  ["south", Proc.new{
	  	say("You can't get out! The handle is stuck and won't budge.") 
	  	}],
	  ["up", "The Mezzanine"],
	  ["down", Proc.new{|p|
	    say("\nYou fall eight feet into the basement and bang up your shoulder and left knee.")
	    p.damage(8)
	    p.move("The Cellar")
	    }]]),
Location.new("The Mezzanine", "The mezzanine overlooks the foyer and has a gold-plated railing. There is a hallway to the east.\n",
	[], [["east", "The Hallway"], ["down", "The Foyer"]]),
Location.new("The Cellar", "It's very dark in here! There is a dusty furnace, a bunch of old chairs, a very curious painting, and you don't see any way out. \n(you're screwed)",
	["minotaur", "bats"], []),
Location.new("The Hallway", "This is a very long hallway with fine but dingy green carpeting. Some curious paintings hang on the walls. West is the mezzanine.\n
	and there are oak doors on both sides. The hallway continues to the east.",
	["butler"], [["west", "The Mezzanine"], ["north", "A Stone Room"], ["south", "The Library"], ["east", "The Red Room"]]),
Location.new("The Antechamber", "You are in a circular, large white room with a high ceiling. Some cobwebs cover the skylight. There are doors west and south.\n You hear some howling noises echoing through the house. South is the foyer.\n",
	["bats"], [["south", "The Foyer"]]),
Location.new("A Stone Room", "This circular room is very, very cold and must and has walls of cobblestone. There is a\n
	giant pit in the center.", ["grim reaper"], [["south", "The Hallway"]]),
Location.new("The Library", "You are in a vast library. The bookshelves are made of oak, and there are many old volumes\n
	here. Cobwebs fill the spaces between the aisles. There is a crystal. chandelier hanging from the ceiling in the center.",
	["zombie", "bats"], [["north", "The Hallway"]]),
Location.new("The well", "A cobblestone well sits on a grassy hill on the grounds of the old mansion.",
	[], [["west", "The Front Yard"], ["down", "The Cellar"]]),
Location.new("The Red Room", "The hallway continues into a large ballroom. There is a stage here, and a large stained glass window 
	to the east.",
["minotaur"], [["west", "The Hallway"]]),
Location.new("The Study", "This is a smaller version of the library, but with a few ratty leather chairs and an extremely
	dusty fireplace.", ["goblin"], [["east", "The Antechamber"]])
],
# Mob types
{
"zombie" => NPC.new("A zombie", 40, 1, "scratch", nil, true),
"bats" => NPC.new("Several bats flying around", 10, 1, "sonic scream", nil, false),
"butler" => NPC.new("The Ghost Butler", 40, 1, "chilling bite", nil, true),
"minotaur" => NPC.new("A minotaur", 60, 2, "claws", nil, true),
"swamp thing" => NPC.new("The swamp thing", 65, 2, "club", nil, true),
"poltergeist" => NPC.new("The Poltergeist", 75, 3, "howl", nil, false),
"goblin" => NPC.new("A green goblin", 3, 85, "dagger", nil, false),
"groundskeeper" => NPC.new("The Groundskeeper", 120, 4, "shovel", nil, false),
"grim reaper" => NPC.new("The grim reaper", 10, 1200, "scythe", nil, true)
})

say "#{COLORS[:red]}THE HAUNTED MANSION#{COLORS[:none]}"
say "=" * 50
say "What's your name, wanderer?"
name = gets.chomp

weapon = ""
validweapons = ["sword", "nunchucks", "axe", "fists"]
while !(validweapons.include?(weapon))
	say "Select a weapon " + validweapons.join(", ")
	weapon = gets.chomp
end
say "You are #{name}, wielding #{weapon}"
p = Player.new(name, 100, 1, weapon, nil)
p.place("The Front Yard")
say "=" * 50
p.location.describe
ctickprocess = Thread.new { World.start_combat_tick }
htickprocess = Thread.new { World.start_heal_tick }
loop do
  validinput = false
  say("")
	while !validinput
		move = gets.chomp.downcase.strip
		exit = p.location.exits.find_index { |exit| exit[0] == move }
    if (move=="look")
    	say("")
      p.location.describe
    elsif ((move=="inv") || (move=="i"))
    	say("#{COLORS[:green]}You are #{p.name}, wielding #{p.weapon}. You have #{p.hp}/#{p.max_hp} HP.\n You have #{p.experience}/#{p.max_experience} experience points.#{COLORS[:none]}")
  	elsif (move == "quit")
  		validinput = true
  	elsif (move == "run away")
  		say("Something compels you to not run away.")
  		validinput = true
  	elsif (move.slice(0, 6) == "attack")
  		subject = move.slice(7, 30)
  		mob = p.location.find(subject)
  		if p.fighting
  			say("You are already fighting!")
  		elsif mob
  		   p.attack(mob)
  		else
  			say("There is no #{subject} here to attack!")
  		end
  		validinput = true
   	elsif ( exit == nil )
  		say("Please enter a valid command.")
  	elsif (p.location.exits[exit][1].class == String)
  		p.move(p.location.exits[exit][1])
  		validinput = true
  	elsif (p.location.exits[exit][1].class == Proc)
  		p.location.exits[exit][1].call(p)
  		validinput = true
  	end

	end
  if (move == "quit")
  	say "#{COLORS[:red]}Goodbye, cruel world.#{COLORS[:none]}"
  	break
  end
end