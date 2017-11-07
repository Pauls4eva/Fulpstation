
// NOTE: FOR ICONS! 	Looks up:   /datums/action.dm   and   _onclick/hud/action_buttons.dm
//				 		Also: carbon/life.dm has handle_changeling(), where the Changeling's displayed chem_charges are updated via its icon.

// 		Spells
// - Added in mob.dm AND mind.dm under AddSpell() (depending on if the spell follows the BODY or the MIND) as obj/effect/proc_holder/spell
// - Spells keep a /datum/action called "action" which attaches to its owner through Grant(), under action.dm

// NOTE : proc_holder lives in modules/spell.dm

// Am I able to use my powers?
/mob/living/proc/BloodsuckerCanUsePowers(var/displaymessage="",) // displaymessage can be something such as "rising from death" for Torpid Sleep.
	if (!getorganslot("heart"))
		if (displaymessage != "")
			to_chat(src, "<span class='warning'>Without a heart, you are incapable of [displaymessage].</span>")
		return 0
	if (!get_bodypart("head"))
		if (displaymessage != "")
			to_chat(src, "<span class='warning'>Without a head, you are incapable of [displaymessage].</span>")
		return 0
	if (!getorgan(/obj/item/organ/brain)) // NOTE: This is mostly just here so we can do one scan for all needed parts when creating a vamp. You probably won't be trying to use powers w/out a brain.
		if (displaymessage != "")
			to_chat(src, "<span class='warning'>Without a brain, you are incapable of [displaymessage].</span>")
		return 0
	return 1



// 			proc_holder VS. action
//
//	/obj/effect/proc_holder - An effect that takes place
//
//	/datum/action - handles the usage of the effect.
//
// NOTE: Check "spell_types" folder for MANY variations (conjure items, )




/obj/effect/proc_holder/spell/bloodsucker
	invocation = ""
	school = "vampiric"
	//action_icon = 'icons/obj/bloodpack.dmi'			// File containing icon
	action_icon = 'icons/Fulpstation/fulpicons.dmi'	// File containing icon
	action_icon_state = "frame"						// State for that image inside icon
	var/action_background_icon = 'icons/Fulpstation/fulpicons.dmi'	// File containing icon background.
	action_background_icon_state = "vamp_power_off"					// Background when OFF
	var/action_background_icon_state_active = "vamp_power_on"		// Background when ON
	charge_max = 0
	range = -1
	clothes_req = 0
	still_recharging_msg = "That power is not ready yet."
	//BS_background_state_enabled = "bg_alien"	// Background: Selected
	var/bloodcost = 0
	var/amToggleable = FALSE						// When used, does this power flip its background ON and OFF to match its ACTIVE state?
	//var/toggleLock = FALSE							// Can I click the button again to disable this power? Or is it always automatic?
	var/amTargetted = FALSE							// When used, does this power require you to click a target? Forces this to use InterceptClickOn().
	var/targetmessage_ON =  "<span class='notice'>The power of your blood flares forth!</span>"
	var/targetmessage_OFF = "<span class='notice'>Your power subsides...</span>"

	// REFERENCE: Base Variables
	//var/panel = "Debug"//What panel the proc holder needs to go on.
	//var/active = FALSE //Used by toggle based abilities.						<------------------- Important! For toggle powers!
	//var/ranged_mousepointer
	//var/mob/living/ranged_ability_user
	//var/ranged_clickcd_override = -1
	//var/has_action = TRUE
	//var/datum/action/spell_action/action = null
	//var/action_icon = 'icons/mob/actions/actions_spells.dmi'
	//var/action_icon_state = "spell_default"
	//var/action_background_icon_state = "bg_spell"

/obj/effect/proc_holder/spell/bloodsucker/Initialize()
	. = ..()
	action.button_icon = action_background_icon // Set background to approptiate file.

/obj/effect/proc_holder/spell/bloodsucker/update_icon()
	if(!action)
		return
	action.background_icon_state = active ? action_background_icon_state_active : action_background_icon_state
	action.UpdateButtonIcon()


// CLICK ICON //	// USE THIS WHEN CLICKING ON THE ICON //
/obj/effect/proc_holder/spell/bloodsucker/Click()
	to_chat(usr, "<span class='warning'>DEBUG: Click() [name]</span>")

	// Power Already On? Cancel.
	if (active)
		if (cancel_check())
			SetActive(FALSE)
		return 0

	// Can We Cast?
	else attempt_cast()

	return 1

// ATTEMPT ENTIRE CASTING OF SPELL //
/obj/effect/proc_holder/spell/bloodsucker/proc/attempt_cast(mob/living/user = usr) // This is done so that Frenzy can try to Feed (usr is EMPTY if called automatically)
	if(cast_check(0, user))	// 1) Can we cast?
		SetActive(TRUE)		// 2) Set spell ACTIVE
		choose_targets(user)// 3) Pick targets (which will then have affects applied)

// SET TOGGLE ACTIVE //	// SETS POWER ON AND OFF, ADDS/REMOVES CLICK INTERCEPTION, AND CAN APPLY EFFECTS/CHECKS TO SEE IF YOU CAN TURN IT OFF
/obj/effect/proc_holder/spell/bloodsucker/proc/SetActive(setActive = 0)//, displayMessage = 1)
	to_chat(usr, "<span class='warning'>DEBUG: SetActive() [name]</span>")

	// Set Toggleables Active
	if (amToggleable)
		// Just a regular toggle?
		if (!amTargetted)
			active = setActive
			update_icon()
		// Click-to-Target? Add/Remove InterceptClickOn() action
		else
			if (setActive)
				add_ranged_ability(usr, targetmessage_ON) // NOTE: These two things set active and update_icon(). //  NOTE: The FALSE is what forces your power, meaning you cannot use one til another is off.
				//add_ranged_ability(usr, displayMessage ? targetmessage_ON : "", FALSE) // NOTE: These two things set active and update_icon(). //  NOTE: The FALSE is what forces your power, meaning you cannot use one til another is off.
			else
				remove_ranged_ability(targetmessage_OFF)
				//remove_ranged_ability(displayMessage ? targetmessage_OFF : "")
		// NOTE ON TOGGLEABLE SPELLS:
		// user add_ranged_ability  and   remove_ranged_ability  in spell.dm to toggle whether or not your next click will use InterceptClickOn


// CAST CHECK //	// USE THIS TO SEE IF WE CAN EVEN ACTIVATE THIS POWER //  Called from Click()
/obj/effect/proc_holder/spell/bloodsucker/cast_check(skipcharge = 0,mob/living/user = usr) //checks if the spell can be cast based on its settings; skipcharge is used when an additional cast_check is called inside the spell
	to_chat(usr, "<span class='warning'>DEBUG: cast_check() [name] / [charge_max] </span>")
	// Not Bloodsucker
	if (!user.mind || !user.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER))
		to_chat(user, "<span class='warning'>You are not a Bloodsucker.</span>")
		return 0
	// Recharge Time, Incapacitation
	if  (!..())
		return 0
	// Am in Frenzy!
	var/datum/antagonist/bloodsucker/bloodsucker = user.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)
	if (bloodsucker.frenzy_state > 1 && usr) // This means, if I am in FRENZY and this power was called by someone CLICKING on me...(otherwise usr would be NULL if called from code)
		to_chat(user, "<span class='warning'>You're lost to Frenzy...you cannot activate powers!</span>")
		return 0
	// Have enough blood?
	if (user.blood_volume < bloodcost)
		to_chat(user, "You need at least [bloodcost] blood to use [name]!</span>")
		return 0
	// DEFAULT VALID!
	return 1

// CANCEL CAST CHECK //	// USE THIS WHEN CLICKING ON AN ALREADY-ON ICON //
/obj/effect/proc_holder/spell/bloodsucker/proc/cancel_check(mob/living/user = usr) // Checks if a toggleable power can be cancelled.
	// We're not even on.
	if (!active)
		return 0
	return 1
	// NOTE: Used by Torpid Sleep to disable use if appropriate.


// DECIDE TARGET //	// USE THIS TO SELECT TURF, PERSON, OR CONTAINER //  Called from Click()
/obj/effect/proc_holder/spell/bloodsucker/choose_targets(mob/living/user = usr)
	to_chat(usr, "<span class='warning'>DEBUG: choose_targets() [name]</span>")
	// Targetted Spell? Cancel out. InterceptClickOn() will do the targetting work
	if (amTargetted)
		return
	var/list/targets = list()
	// targets += ADD_TARGET_HERE
	// if (!can_target(ADD_TARGET_HERE)) // Do a LOOP through targets to see if they're valid
	//	return
	// CAST SPELL
	perform(targets, user) // Runs: before_cast(), invocation() [say a line], playMagSound() [aka play the spell's sound], critfail(), cast() [seen BELOW], after_cast(), and updates the button icon.

// CLICK ON TARGET //	// USE THIS WHEN CLICKING ON A TARGET //  Called from action, when add_ranged_ability is on.
/obj/effect/proc_holder/spell/bloodsucker/InterceptClickOn(mob/living/caller, params, atom/A)
	to_chat(usr, "<span class='warning'>DEBUG: InterceptClickOn() [name]</span>")
	if (..())			// For SOME REASON, we return FALSE if ..() returns TRUE. Go figure.
		return 0
	if (!cast_check(1)) // One more Cast Check (this time with Charged disabled...countdown timer has already been affected to get here)
		SetActive(FALSE)
		revert_cast()
		return 1
	if (!can_target(A)) // Now let's see if we picked a valid target. If not, we need to tell the calling function we're not done with InterceptClickOn, and can keep trying targets.
		return 0
	var/list/targets = list()
	targets += A
	// CAST SPELL
	perform(targets, usr) // Runs: before_cast(), invocation() [say a line], playMagSound() [aka play the spell's sound], critfail(), cast() [seen BELOW], after_cast(), and updates the button icon.
	return 1

// TARGET VALID? //	// USE THIS TO DETERMINE IF TARGET IS VALID //
/obj/effect/proc_holder/spell/bloodsucker/can_target(atom/A)//mob/living/target)
	to_chat(usr, "<span class='warning'>DEBUG: can_target() [name]</span>")
	return TRUE

// APPLY EFFECT //	// USE THIS FOR THE SPELL EFFECT //
/obj/effect/proc_holder/spell/bloodsucker/cast(list/targets, mob/living/user = usr)
	to_chat(usr, "<span class='warning'>DEBUG: cast() [name]</span>")
	// Default: Spend Blood
	user.blood_volume -= bloodcost


// ABORT SPELL //	// USE THIS WHEN FAILING MID-SPELL. NOT THE SAME AS DISABLING BY CLICKING BUTTON //
/obj/effect/proc_holder/spell/bloodsucker/proc/cancel_spell()
	to_chat(usr, "<span class='warning'>DEBUG: cancel_spell() [name]</span>")
	// Disable Icon
	SetActive(FALSE)

// CONTINUE CHECK //	// USE THIS WITH do_mob() TO KEEP SPELL ACTIVE
/obj/effect/proc_holder/spell/bloodsucker/proc/continue_invalid()
	to_chat(usr, "<span class='warning'>DEBUG: continue_invalid() [name]</span>")
	charge_counter = 0 // Reset timer.
	return 1













/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//obj/effect/proc_holder/spell/targeted/touch/feed
/obj/effect/proc_holder/spell/bloodsucker/feed
	name = "Feed"
	desc = "Draw the heartsblood of the living."
	amToggleable = TRUE
	action_icon_state = "power_feed"				// State for that image inside icon

	//charge_max = 10


// CAST CHECK //	// USE THIS WHEN CLICKING ON THE ICON //
/obj/effect/proc_holder/spell/bloodsucker/feed/cast_check(skipcharge = 0,mob/living/user = usr) //checks if the spell can be cast based on its settings; skipcharge is used when an additional cast_check is called inside the spell
	if(!..())// DEFAULT CHECKS
		return 0
	// No Target
	if (!user.pulling)
		to_chat(user, "<span class='warning'>You must be grabbing a victim to feed from them.</span>")
		return 0
	// Not even living!
	if (!isliving(user.pulling) || issilicon(user.pulling))
		to_chat(user, "<span class='warning'>You must be grabbing a victim to feed from them.</span>")
		return 0
	// No Blood / Incorrect Target Type
	var/mob/living/carbon/target = user.pulling
	if (!iscarbon(user.pulling) || target.blood_volume <= 0)
		to_chat(user, "<span class='warning'>Your victim has no blood to take!</span>")
		return 0
	var/mob/living/carbon/human/H = user.pulling
	if (ishuman(user.pulling) && NOBLOOD in H.dna.species.species_traits)// || user.get_blood_id() != target.get_blood_id())
		to_chat(user, "<span class='warning'>Your victim's blood is not suitable for you to take!</span>")
		return 0
	// No Target / Not in correct state
	if (user.grab_state < GRAB_AGGRESSIVE)
		to_chat(user, "<span class='warning'>You don't have a tight enough grip on your victim!</span>")
		return 0
	// Wearing mask
	if (user.is_mouth_covered())
		to_chat(user, "<span class='warning'>You cannot feed with your mouth covered! Remove your mask.</span>")
		return 0
	// DONE!
	return 1


// POST-CLICK TARGET //	// USE THIS TO SELECT TURF, PERSON, OR CONTAINER //  Called from Click()
/obj/effect/proc_holder/spell/bloodsucker/feed/choose_targets(mob/living/user = usr)
	var/list/targets = list()
	targets += user.pulling
	// CAST SPELL
	perform(targets, user) // Runs: before_cast(), invocation() [say a line], playMagSound() [aka play the spell's sound], critfail(), cast() [seen BELOW], after_cast(), and updates the button icon.


// APPLY EFFECT //	// USE THIS FOR THE SPELL EFFECT //
/obj/effect/proc_holder/spell/bloodsucker/feed/cast(list/targets, mob/living/user = usr)
	..() // DEFAULT

	var/datum/antagonist/bloodsucker/bloodsuckerdatum = user.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)
	var/mob/living/carbon/target = targets[1]

	// Initial Wait
	to_chat(user, "<span class='warning'>You pull [target] close to you and draw out your fangs...</span>")
	sleep(10)
	if (!user.pulling || !target) // Cancel. They're gone.
		cancel_spell()
		return

	// Put target to Sleep (if valid)
	if(!target.mind || !target.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER))
		target.Sleeping(50,0) 	  // SetSleeping() only changes sleep if the input is higher than the current value. AdjustSleeping() adds or subtracts //
		target.Unconscious(50,1)  // SetUnconscious() only changes sleep if the input is higher than the current value. AdjustUnconscious() adds or subtracts //
	target.Move(user.loc)
	sleep(5)

	// Broadcast Message
	user.visible_message("<span class='warning'>[user] closes their mouth around [target]'s neck!</span>", \
						 "<span class='warning'>You sink your fangs into [target]'s neck.</span>")
	// Begin Feed Loop
	var/warning_target_inhuman = 0
	var/warning_target_dead = 0
	var/warning_full = 0
	while (bloodsuckerdatum && target && active)
		user.canmove = 0 // Prevents spilling blood accidentally.

		// Abort? A bloody mistake.
		if (!do_mob(user, target, 20, 0, 0) && active) // We check "active" becuase you may have turned off your power during this do_mob. //, extra_checks=CALLBACK(src, /obj/effect/proc_holder/spell/bloodsucker/proc/continue_invalid))) // user / target / time / uninterruptable / show progress bar / extra checks
		// Note: For future do_mob, everything in CALLBACK after the proc is its input. just keep adding things after the comma.
			to_chat(user, "<span class='warning'>Your feeding has been interrupted!</span>")
			user.visible_message("<span class='danger'>[user] is ripped from [target]'s throat. Blood sprays everywhere!</span>", \
					 			 "<span class='userdanger'>Your teeth are ripped from [target]'s throat, creating a bloody mess!</span>")
			// Deal Damage to Target (should have been more careful!)
			target.bleed(30)
			playsound(get_turf(target), 'sound/effects/splat.ogg', 40, 1)
			if (ishuman(target))
				var/mob/living/carbon/human/H = target
				H.bleed_rate += 20
			target.add_splatter_floor(get_turf(target))
			user.add_mob_blood(target)
			target.add_mob_blood(target)
			target.take_overall_damage(10,0)
			target.emote("scream")

			// Lost Target & End
			cancel_spell()
			return
		///////////////////////////////////////////////////////////
		// 		Handle Feeding! User & Victim Effects (per tick)
		bloodsuckerdatum.handle_feed_blood(target)
		///////////////////////////////////////////////////////////
		// Done?
		if (target.blood_volume <= 0)
			to_chat(user, "<span class='notice'>You have bled your victim dry.</span>")
			break
		// Not Human?
		if (!warning_target_inhuman && !ishuman(target))
			to_chat(user, "<span class='notice'>You recoil at the taste of a lesser lifeform.</span>")
			warning_target_inhuman = 1
		// Dead Blood?
		if (!warning_target_dead && target.stat == DEAD)
			to_chat(user, "<span class='notice'>Your victim is dead. Its blood barely nourishes you.</span>")
			warning_target_dead = 1
		// Full?
		if (!warning_full && user.blood_volume >= bloodsuckerdatum.maxBloodVolume)
			to_chat(user, "<span class='notice'>You are full. Any further blood you take will be wasted.</span>")
			warning_full = 1

		// END WHILE
	sleep(20) // If we ended via normal means, end here.
	cancel_spell()
	user.visible_message("<span class='warning'>[user] unclenches their teeth from [target]'s neck.</span>", \
						 "<span class='warning'>You retract your fangs and release [target] from your bite.</span>")


// ABORT SPELL //	// USE THIS WHEN CANCELLING A SPELL //
/obj/effect/proc_holder/spell/bloodsucker/feed/cancel_spell()
	var/mob/living/L = usr
	L.update_canmove()
	..() // Set Active FALSE


// CONTINUE CHECK //	// USE THIS WITH do_mob() TO KEEP SPELL ACTIVE
/obj/effect/proc_holder/spell/bloodsucker/feed/continue_invalid()
	return !usr.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)













/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//obj/effect/proc_holder/spell/targeted/touch/expelblood
/obj/effect/proc_holder/spell/bloodsucker/expelblood
	name = "Expel Blood"
	desc = "Secrete some of your blood as an addictive, healing goo. Feeding it to blood-drained corpses turns mortals to Bloodsuckers."
	invocation = ""
	school = "vampiric"
	bloodcost = 10
	amToggleable = TRUE
	amTargetted = TRUE
	targetmessage_ON =  "<span class='notice'>You open your wrist. Choose what, or whom, will receive your blood.</span>"
	targetmessage_OFF = "<span class='notice'>The wound on your wrist heals instantly.</span>"
	//charge_max = 10
	action_icon_state = "power_bleed"				// State for that image inside icon


// TARGET VALID? //	// USE THIS TO DETERMINE IF TARGET IS VALID //
/obj/effect/proc_holder/spell/bloodsucker/expelblood/can_target(atom/A)//mob/living/target)
	if (!..())
		return 0

	var/atom/target = A
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = usr.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)

	// REMEMBER: We return 1 if we want to go on to the "Cast" portion. That means targetting turf should NOT continue.

	// Out of Range
	if (!(target in range(1, get_turf(usr))))
		return 0
	// Target Self
	if(target == usr)
		to_chat(usr, "<span class='notice'>You cannot target yourself.</span>")
		return 0
	// Target Type: Carbon
	if (iscarbon(target))
		var/mob/living/carbon/M = target
		// Target Mouth Covered
		if (M.is_mouth_covered()) // if(!canconsume(M, usr))
			to_chat(usr, "<span class='notice'>[target] has [M.p_their()] mouth covered.</span>")
			return 0
		// Message
		M.visible_message("<span class='notice'>[usr] places their wrist to [M]'s mouth.</span>", \
						  "<span class='userdanger'>[usr] puts their bloodied wrist to your mouth!</span>")
		// Timer...
		if(!do_mob(usr, M, 30))
			to_chat(usr, "<span class='notice'>The transfer was interrupted!</span>")
			return 0
		// Success Message
		to_chat(usr, "<span class='notice'>[M] consumes some blood from your veins.</span>")
		to_chat(M, "<span class='notice'>You consume some blood from the veins of [usr].</span>")
		playsound(M.loc,'sound/items/drink.ogg', rand(30,40), 1)

	// Target Type: Living
	else if (isliving(target))
		to_chat(usr, "<span class='notice'>[src] cannot take your blood.</span>")
		return 0

	// Target Type: Container
	else if (istype(target, /obj/item/reagent_containers))
		if (target.reagents.maximum_volume - target.reagents.total_volume > 0) // Only tell them they succeeded if there is space for blood.
			to_chat(usr, "<span class='notice'>You expel some blood into the [target].</span>")
		return 1

	// Target Type: Floor
	else if (isturf(target))
		// Timer...
		if(!do_mob(usr, target, 30))
			//to_chat(usr, "<span class='notice'>The desecration was interrupted!</span>")
			return 0
		// Create Splat
		var/obj/effect/decal/cleanable/blood/vampblood/b = new /obj/effect/decal/cleanable/blood/vampblood(target, usr.mind)
		b.MatchToCreator(usr) // Set Creator, DNA, and Diseases
		// Subtract Blood, Play Sound.
		bloodsuckerdatum.set_blood_volume(-10)
		playsound(b.loc,'sound/effects/splat.ogg', rand(30,40), 1)	//return 0
		to_chat(usr, "<span class='notice'>You desecrate the [get_area(target)].</span>")
		cancel_spell()
		return 0
	//Target Type: Item, etc. (FAIL)
	else
		return 0

// APPLY EFFECT //	// USE THIS FOR THE SPELL EFFECT //
/obj/effect/proc_holder/spell/bloodsucker/expelblood/cast(list/targets, mob/living/user = usr)
	..() // DEFAULT

	var/atom/target = targets[1]
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = user.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)

		// BLOOD TRANSFER //
	var/maxTransfer = min(10, user.blood_volume)
	to_chat(user, "<span class='notice'>DEBUG: Expel Blood - [target]</span>")
	to_chat(user, "<span class='notice'>DEBUG: Expel Blood - [target.reagents]</span>")
	maxTransfer = min(10, target.reagents.maximum_volume - target.reagents.total_volume)
	if (maxTransfer == 0)
		to_chat(user, "<span class='notice'>That container is full.</span>")
		return 1
	// Deduct from Bloodsucker...
	bloodsuckerdatum.set_blood_volume(-maxTransfer)
	// Get Vamp's Blood Data

	// Create Temporary Reagent Container and Fill It
	var/datum/reagents/tempreagents = new(999) // 999 Max Cap.  																// NOTE: Why are we creating a NEW reagents container and not just transferring from the Vamp's reagents? Because we don't want
	tempreagents.add_reagent("vampblood", maxTransfer, user.get_blood_data(user.get_blood_id()), user.bodytemperature)	// reaction() to react with EVERYTHING in the Vamp's stomach. So we create a tidy little container, share it, and destroy it.
	// Give Blood from Container
	tempreagents.reaction(target, INGEST)//  , 1) // The 1 means transfer all contents.
	tempreagents.trans_to(target, tempreagents.total_volume)
	// Kill Temporary Reagent Container
	qdel(tempreagents)

	//cancel_spell()  // NOTE: We don't want to turn off Expel Blood, do we?
	return 1


















/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/effect/proc_holder/spell/bloodsucker/torpidsleep
	name = "Torpid Sleep"
	desc = "Enter a deathlike sleep. You will heal even terrible wounds with your blood...but you will not rise again until your physical wounds are healed."
	invocation = ""
	school = "vampiric"
	amToggleable = TRUE
	//toggleLock = TRUE
	targetmessage_ON =  ""//"<span class='notice'>Your pulse starts again. You feel...almost human.</span>"
	targetmessage_OFF = ""//"<span class='notice'>You shrug off the disguise of frail human weakness. You are powerful once more.</span>"
	stat_allowed = DEAD
	charge_max = 100
	action_icon_state = "power_torpor"				// State for that image inside icon


// CAST CHECK //	// USE THIS WHEN CLICKING ON THE ICON //
/obj/effect/proc_holder/spell/bloodsucker/torpidsleep/cast_check(skipcharge = 0,mob/living/user = usr) //checks if the spell can be cast based on its settings; skipcharge is used when an additional cast_check is called inside the spell
	if (user.AmStaked()) // Located in bloodsucker_items
		to_chat(user, "<span class='danger'>With a stake in your heart, you cannot regenerate!</span>")
		return 0
	if(!..())// DEFAULT CHECKS
		return 0
	if (!user.BloodsuckerCanUsePowers("rising from death"))//if (!user.getorganslot("heart"))
		return 0
	//if (src.active)
	//	to_chat(user, "<span class='warning'>You're already attempting to regenerate.</span>")
	//	return 0
	if(!user.stat) // Taken from Changeling, confirms that you WANT to do this even though you're alive currently.
		switch(alert("Do you wish to pass into Torpid Sleep?",,"Yes", "No"))
			if("No")
				return 0
	// DONE!
	return 1

// CANCEL CAST CHECK //	// USE THIS WHEN CLICKING ON AN ALREADY-ON ICON //
/obj/effect/proc_holder/spell/bloodsucker/torpidsleep/cancel_check(mob/living/user = usr)
	if (!..())// DEFAULT CHECKS
		return 0
	// Not if Damaged or Missing Limbs
	//var/mob/living/carbon/C = owner.current
	//var/list/missing = owner.current.get_missing_limbs()
	//if (C.get_damaged_bodyparts(TRUE, TRUE) || missing.len)
	//	to_chat(user, "<span class='warning'>You will rise again when all your corporeal wounds are healed.</span>")
	//	return 0

	// Cancel! You leave this automatically.
	to_chat(user, "<span class='warning'>You will rise again when all your corporeal wounds are healed.</span>")
	return 0



// APPLY EFFECT //	// USE THIS FOR THE SPELL EFFECT //
/obj/effect/proc_holder/spell/bloodsucker/torpidsleep/cast(list/targets, mob/living/user = usr)
	..() // DEFAULT

	// Already Alive? "Kill" me.
	if(user.stat != DEAD)
		to_chat(user, "<span class='notice'>You give in to the call of an ancient sleep. The light of this world fades...</span>")
		user.emote("deathgasp")
		user.tod = worldtime2text()
		user.status_flags |= FAKEDEATH //play dead
		user.update_stat()
		user.update_canmove()

	sleep(50) // 5 seconds...
	to_chat(user, "<span class='notice'>The lividity of your corpse drains away. Your parched veins pulse...</span>")
	sleep(50) // 5 second wait until healing starts.

	// Time to Heal!
	if (user.blood_volume > 0)
		to_chat(user, "<span class='warning'>Your vampiric blood sets itself to work repairing your body!</span>")
	// Values
	var/healingnotice = 0	//
	var/healingcomplete = 0	// Did I complete my healing? Or was I brought out of death by outside means?
	var/tickerupdate = 20	// Every now and then, let the player know he's still playing the game.
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = usr.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)
	while (!healingcomplete && bloodsuckerdatum)// Just keep going while we're a vampire.
		// Staking Cancels
		if (user.AmStaked())
			to_chat(user, "<span class='userdanger'>The stake in your heart abruptly ends your sleep! You will remain dead until it is removed.</span>")
			if (user.stat < DEAD)
				user.death(0) // Kill me if alive.
			healingcomplete = 0
			break

		// Update Message
		if (user.blood_volume > 0)
			tickerupdate --
			if (tickerupdate <= 0)
				tickerupdate = 20
				var/torpormessage = pick("Dreams of the abyss...","Blackness clouds your dreams...","Bats, and death...","Your black soul, exposed...","Eyes, watching, always watching...","Cruel hunger and despair...","Cobwebs...")
				to_chat(user, "<i>[torpormessage]</i>")

		// Healed Enough to SLEEP instead of DIE?
		if (user.stat == DEAD && user.can_be_revived())
			user.status_flags |= FAKEDEATH //play dead
			user.revive(0)
			to_chat(user, "<span class='warning'>You crawl back from the brink of Final Death. You will remain torpid until your wounds recover.</span>")

		sleep (10) // Sleep 1.5 second...

		// Not Dead Anymore? Break WITHOUT healing complete.
		if (!(user.status_flags & FAKEDEATH || user.stat == DEAD))
			break

		// Not able to heal anymore? Hard abort!
		if (!user.BloodsuckerCanUsePowers())
			to_chat(user, "<span class='warning'>You are suddenly incapable of regenerating any further!</span>")
			//end_power(null, null, 0) // This ends the power, but without altering anything but the ICON and the ACTIVE status.
			return;

		// WARNING: Stopped Healing
		if (user.blood_volume <= 0 && !healingnotice)
			healingnotice = 1
			to_chat(user, "<span class='warning'>You've run out of blood before your body was repaired. You'll remain dead until blood is somehow fed to you...</span>")
			continue
		else if (user.blood_volume > 0)
			healingnotice = 0

		// Heal: Basic
		if (bloodsuckerdatum.handle_healing_natural(3)) // Did we heal? Then continue to next tick until we're done healing.
			continue

		// Heal: Advanced
		if (bloodsuckerdatum.handle_healing_torpid()) // Did we heal a limb or organ?
			continue

		// No damage. Break!
		to_chat(user, "<span class='notice'>You rise again!</span>")
		user.tod = null

		// HEAL UP: Taken from fully_heal in living.dm
		user.setToxLoss(0, 0) //zero as second argument not automatically call updatehealth().
		user.setOxyLoss(0, 0)
		user.setCloneLoss(0, 0)
		user.setBrainLoss(0)
		user.setStaminaLoss(0, 0)
		user.SetUnconscious(0, FALSE)
		user.set_disgust(0)
		user.SetStun(0, FALSE)
		user.SetKnockdown(0, FALSE)
		user.SetSleeping(0, FALSE)
		user.radiation = 0
		user.set_blindness(0)
		user.set_blurriness(0)
		user.set_eye_damage(0)
		user.cure_nearsighted()
		user.cure_blind()
		user.heal_overall_damage(100000, 100000, 0, 0, 1) //heal brute and burn dmg on both organic and robotic limbs, and update health right away.
		user.ExtinguishMob()
		user.update_canmove()
		//user.revive(1) // A FULL heal. Takes care of all the little things that blood may have missed healing.
		break

	// DONE! Wipe fake death.
	cancel_spell()


// ABORT SPELL //	// USE THIS WHEN CANCELLING A SPELL //
/obj/effect/proc_holder/spell/bloodsucker/torpidsleep/cancel_spell()
	usr.status_flags &= ~(FAKEDEATH) // Remove it
	..() // Set Active FALSE













/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/effect/proc_holder/spell/bloodsucker/humandisguise
	name = "Mortal Disguise"
	desc = "Compel your corpselike physiology to imitate a human's. Low blood will make you faint, your wounds will stop healing automatically, your body temperature will return to normal, and you can stomach human food."
	invocation = ""
	school = "vampiric"
	amToggleable = TRUE
	//include_user = 1
	stat_allowed = UNCONSCIOUS
	charge_max = 50
	action_icon_state = "power_human"				// State for that image inside icon
	targetmessage_ON =  "<span class='notice'>Your pulse starts again. You feel...almost human.</span>"
	targetmessage_OFF = "<span class='notice'>You shrug off the disguise of frail human weakness. You are powerful once more.</span>"


// SET TOGGLE ACTIVE
/obj/effect/proc_holder/spell/bloodsucker/humandisguise/SetActive(setActive = 0)
	..() // DEFAULT

		// Set Values
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = usr.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)
	bloodsuckerdatum.poweron_humandisguise = active

	// Display Message Line
	to_chat(usr, "<span class='notice'>[active ? targetmessage_ON : targetmessage_OFF]</span>")