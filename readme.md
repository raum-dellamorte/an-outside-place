An Outside Place (Name Subject To Change)
=========================================

###### A game written in Odin with Raylib.

### Odin Praise / Compile Instructions

Odin is good.

Compiles with [Odin version dev-2025-01](https://github.com/odin-lang/Odin/tree/dev-2025-01)

Tested on Linux and MacOS.

At the moment, `odin run .` is what you need to run it. Installing Odin is beyond the scope of this Readme.md, and will remain so until such time as I change my mind.

## Goal of this Project

I've had a combat system in my head for a long time that is mostly inspired by Parasite Eve but converted into a kind of tactics combat system akin to Divinity: Original Sin and the like.

- Everything you can do in combat is an Action.
  - Moving, attacking, using items, casting spells, all Actions.
  - Your characters will have most likely 2 or 3 Action Slots.
  - Time passes for the Actions in each Slot simultaneously.
    - You may be using one Action Slot to move your character, another to get a spell ready to cast, and if you're OP, perhaps you're drinking a potion while you move.
    - Some Actions may temporarily prevent other Actions from processing (described below as 'blocking').
      - You could be preparing to cast a spell that takes all your concentration, preventing you from moving or defending yourself.
- Turn order is decided by how long your Actions take.
  - Actions have a Prep stage, Perform/Cast stage, and Cooldown stage.
    - All stages are measured in Seconds.
    - If Perform/Cast is more than 1 Second, it's Damage/Healing Over Time.
      - Movement will be 0 Prep but Perform time and Cooldown time will be based on distance, whether you're walking or running, and character stats like Dexterity, Athletics, Endurance, and/or Stamina. To Be Determined.
      - Perhaps your character depletes their Stamina while running, this would cause the Cooldown to become blocking, as described below.
    - Prep and Cooldown stages can be blocking, preventing other Actions from being processed. This means the blocking Prep or Cooldown is preventing time from passing for any other Action.
      - Blocking Prep is a state of total concentration.
      - Blocking Cooldown is a state of exhaustion.
    - As stated above in the section about Action Slots, if no blocking stages are being processed (consuming time), time passes for all Actions simultaneously.
    - Regular Cooldown is only to prevent immediate reuse of the same Action and the used Action Slot will be made available for a different Action.
  - Seconds wherein no Action is in the Perform/Cast stage are skipped and only used to determine order of events / turn order.
    - If you and the enemy started Prep at the same time, your Prep being 10 Seconds, the Enemy's is 8 Seconds, the Enemy Performs their Action first. But you may have been able to choose an Action with 5 Seconds of Prep which would have you Perform first.

    The idea is to simulate real time strategy while presenting as turn based strategy. Menu driven combat with "realistic" turn order. The strategy is in the actions you choose because they determine when you get to choose your next action.

    In FFVII there was an Active Time system, and this is like that except you don't have to wait for your character's AT bar to fill, time just jumps to who would be next.

    In Parasite Eve you can move around freely in combat and when you're ready to attack, time stops while you choose your action from a menu. The main difference compared with what I want to do is that movement is going to be plotted out similar to Divinity: Original Sin and Baldur's Gate 3 (and presumably Gates 1 and 2?).

    Let's say you're playing a character with better reflexes than you. If you're playing in real time, then that character is hindered by your control. I don't know about you, but for me, that's quite a hindrance. This combat system is as inspired by my want to simulate superhuman reflexes and lightning fast tactical decision making prowess as it is by the aforementioned games. I guess that makes it a power fantasy... Oh yeah, it's a video game. Even Dark Souls, no matter how many attempts it takes to defeat the first boss, is a power fantasy. You just kept on resurrecting until you showed that puny god what-for. Note to self: Be like a JRPG and let the player kill a god here and there.

## Status:

- Graphics are not a priority so it's just Cubes fightin' other Cubes atm.
  - FIXME: If you die you can still move around but you can't pass through anything you haven't already killed (walls remain unimplemented, just live and dead Cubes). This is not a priority until the combat system is in a playable state. 
    - That gave me an idea for a maze wherein you have to defeat enemy obstacles to get by them. When dead you can't pass through living things or kill them, but you can now pass through spirit gates. You have to resurrect yourself to finish the maze. So you'll need to figure out when you need to be alive and when you need to be dead. Could be a mini game?
- Overly complicated FPS display **now working**.
  - I'm not using `rl.SetTargetFPS` or `rl.DrawFPS`. I rolled my own system for framerate independent movement which in turn made getting the effective FPS tricky. Actual FPS is much higher than what I display because movement is not processed until the next 60th of a second and the meantime is filled with Draw calls. Perhaps it's a bad idea to use Draw calls as a way of twiddling CPU/GPU thumbs. I won't know till much much later.
- The next major goal is Menu Driven Combat!

## Setting / Story

###### We, Here At Raum Dellamorte, apologise For The Long Intro To A Game That Will Never Be

**The Nothing** consumes the past of all that recently was, and ever strives to capture the present within its jaws in order to eliminate the future and return all things to **The Void**, **The Abyss**, from which existence was stolen by *That Which Cannot Be, Yet Is*.

    Islands of things, pockets of existence, are here in the belly of **That Which Is Not**, as the wait to be broken down and dissolved in the digestive juices of **The Never**. *That Which Cannot Be*, *That Which Must Not Be*, laughs in the distance as it litters what should be a void with *Space and Time* and *living things* and ***crystalline structures***. All things created, all what is, exists as insult to **That Which Is Not**, **The Nothing**, **The Never**, **The Abyss, The Void**.

    As a pitiful *living thing*, or perhaps the shadow of one, you awake in this place which is becoming not a place. Lost in the islands of past places dissolving into **Naught**, you can accept your fate and be nothing, or, if you're not quite ready, there are options.

    You may think of escape... Is it even possible to escape to where the *living* thrive in their sin against **That Which Is Not**? Can you fight your way to *The Present*, finding paths from island to island in hopes of getting closer to escaping **The Abyss**? It may be challenging without *divine favour*.

    You may understand that all must be returned to **The Nothing**, and so decide to serve as a digestive aid, helping to break down some of the more stubborn *living things* in this place. Perhaps you could earn the favour of **That Which Is Not** and ascend to *The Present* as representative of **The Void**, Mercenary of **The Abyss**.

    Or perhaps you are a trouble maker? It may be ***The Chaos***, ***The Noise***, ***The Instability*** that you would align yourself with, like those naughty ***Sins of the Elements***. No loyalties tug at your soul. No will to live, no will to die, only the will to create and destroy. By accident of purposelessness you stand in opposition and aid to creation and  destruction, achieving balance with no forethought or aim. It is not about being, it is about doing. Doing whatever comes to mind. Kill, resurrect, steal, donate, unite, alienate. These islands in the belly of **The Void** are a playground for a shadow of the living seeking to become a ***Sin***.

    Championing life may be challenging above all, for *The Creator*, *The Thief*, knows you not. You must serve *Existence* with loyalty and tenacity, with no hope of help if help you hope for. You are in the shadow beyond its vile realm and if you are to be seen you must make yourself a beacon bright enough to shine through the gnashing teeth of **The Void**, and only then may you have a chance to earn the favour of *The Creator*, *The Sin That Betrayed Chaos*, *Thief Of The Crown Of Existence*. Even <u>The Narrator</u> is against you and your love of *pretty little flowers* and whatnot.

    Where was I? Sorry. Anyway, it's probably best just to give up, sit by the edge, and wait for all that you were to dissolve into **The Abyss**.
