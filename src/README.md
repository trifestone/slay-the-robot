# Slay The Robot

Slay the Robot is a comprehensive framework for Godot 4 which enables and streamlines the creation of roguelike deckbuilders similar to Slay the Spire.

# Features

*Some of the core features include but are not limited to:*

## 🃏 Cards, Cards, and More Cards

Cards have a massive and robust data-driven API, allowing you to create cards from simple JSON payloads. Almost every card in Slay the Spire is possible with this framework, many even possible without having to touch a single line of code, just by using the existing actions and card properties provided in the default framework.

Got too many cards? Nonsense! Use card packs to query and organize even thousands of cards in a performant manner. Add a new red card to the game? The red card pack will instantly add it to the red deck and they'll start showing up. Want to suddenly start being able to draft green cards during a run? Simply add a green card pack to the player and it'll automatically sort out the rest.

## ⚔️ Action System

A system of reusable action scripts drives everything. From attacking and drawing cards, to buying things from a shop, to more technical things like generating the world, ending your turn, or incrementing a status effect all pipe through this system in an orderly and consistent fashion. There's even actions that make or modify other actions, allowing for deep nested behavior.

A value hierarchy ensures you have total control over where data is pulled. Restrict action parameters to a single action, or provide them to your cards so all actions inherit from them. Or even assign custom values to the player themself and pull data from there.

Actions can be assigned timers to ensure they take exactly as long as you need them to. Both synchronous and asynchronous actions are also supported. Maybe you want a card that torrents the entirety of Bee Movie, plays it, and makes the player sit through to the end before they can play another card. Hey, I'm not here to judge your impeccable taste.

## 📜 Interceptors

Data driven behavior not enough? Want to attach scripts to other scripts, setting off crazy chains that mess with the game's own internal systems through status effects and relics? Actions can be dynamically modified by action interceptors right before they run, creating complex and consistent interactions with minimal code.

Prevent the player from drawing cards, make shops more expensive, preserve your block between turns, make it so attacks hit harder, expand the amount of cards you can have in your hand? All easily possible with interceptors by writing short scripts and specifying what actions they affect and how.

## 🤔 Validators 

Validators drive conditional logic across the UI and game logic. Want to restrict a card to being only played under certain conditions? How about glow if there's 3 enemies? Perhaps have some additional effect when played if you have 7+ cards in hand? Maybe it only plays when the [International Space Station's urine tank is full](https://github.com/Stovoy/pISSStreamGodot)? Easy.

## 📖 Events and Dialogue

Both combat and non combat events are supported. A simple but powerful state machine driven dialogue system ensures you can write whatever events you need. Event pools control exactly what kind of events can show up and when.

## 🏃 Acts, Ascensions, and Custom Runs

A 3-Act structure is provided by default, with a custom run modifier for endless mode. Branching acts are also supported. Run modifiers and "ascensions" are handled by the same tech, making it easy to add more.

A system for run start options is also provided. Want to choose between losing all your money to gain a rare card, or maybe gain a random common artifact? Decisions decisions...

## 🎲 Deterministic RNG

Random number generation is extremely important to card games and great care has been taken to ensure deterministic behavior. Automatically generate "tracks" of RNG and dependency inject them into your actions with ease. Things like shuffling your deck, events, random card damage, and much more have all been sorted into non competing buckets so the same behavior happens every time. This ensures that no matter how hard you save scum, you'll still lose.

## 🧮 Combat Stats

The combat system keeps track of everything that happens, and can be queried on a per turn or per combat basis. These can be hooked into to provide cards with conditional effects. You or users can even provide custom stats.

## 💾 Saving and Loading

The framework handles all the scary data handling work for you, automatically. Simply extend from SerializableData and add @export to a variable, and you can save and load even complex nested objects with ease in human readable JSON.

The game manages autosaves for player data all on its own, and keeps track of wins and losses in total and for each character.

## ⚙️Mod Support

The same technology that streamlines saving and loading also makes mod support a breeze. Data, assets, and scripts (including your own!) can be loaded from external files.

Simply create a mod_info.json file, specify which folders to load from and what data types it represents, and it will automatically load them if enabled in mod_list.json. Scripts may also be trivially loaded in, allowing users to inject new behavior into the game or override existing scripts.

An example mod has been provided to see this technology in action.

## ⚖️ Permissive Lisense

Under the MIT Lisense you're free to use this framework for anything and it's yours to do as you please, from hobby to commercial.

## And So Much More

Rest actions, shops, chests, consumables, status effects, artifacts. This framework has everything you need to make your dream deckbuilder.

# Requirements

Slay the Robot is written in Godot 4.4 via GDScript, which can be downloaded from the official site [here](https://godotengine.org/download/archive/4.4-stable/).

![Sample Image](https://raw.githubusercontent.com/godotengine/godot/master/logo_outlined.svg)