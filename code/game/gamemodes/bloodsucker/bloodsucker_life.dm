
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			HANDLE BLOODSUCKER

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// All my Main Checks! This Loop is created from datum_bloodsucker on creation.


/mob/living/proc/AmBloodsucker(checkHumanDisguise=0) // checkHumanDisguise:  TRUE means that we are NOT a bloodsucker if human disguise is on. FALSE means it doesn't matter, we only want to know what we are.
	// No Datum
	if (!mind || !mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER))
		return FALSE
	// Am 100% Vamp
	if (!checkHumanDisguise)
		return TRUE
	// Am I disguised as human?
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)
	return bloodsuckerdatum.poweron_humandisguise


/datum/antagonist/bloodsucker/proc/handle_life() // Should probably run from life.dm, same as handle_changeling
	set waitfor = FALSE // Don't make on_gain() wait for this function to finish. This lets this code run on the side.

	// Loop forever while I'm still a Bloodsucker.
	while (owner.has_antag_datum(ANTAG_DATUM_BLOODSUCKER))

		// If pretending to be human, then don't do any of this stuff.
		if (poweron_humandisguise)
			sleep(10)
			continue
		// If not alive...
		if (!owner.current || owner.current.stat)
			sleep(10)
			continue

		// metabolism_efficiency <---this is covered in handle_chemicals_in_body() below, but let's see how it can be used

		// Handle O2 and Tox. We do this here, not in Healing, because it must apply when we're dead, but not while faking human.
		owner.current.setOxyLoss(0)
		owner.current.setToxLoss(0)

		// Shift Bloodsucker Temperature to Location's Temp
		var/turf/userturf = get_turf(owner.current)
		owner.current.bodytemperature += round((userturf.temperature - owner.current.bodytemperature) / 250, 0.1)   // Constantly blend toward the temperature of the current environment.

		// Values to Affect        <---- All from handle_status_effects() in carbon/life.dm
								// THESE are from living/status_procs.dm
								// confused, dizziness, drowsyness, jitteriness, stuttering, slurring, silent, druggy, hallucination, drunkenness
								// set_blindness(var_value), set_eye_damage(var_value), set_blurriness(var_value)
		// Run Blood Stuff
		handle_blood()

		// Wait before next pass
		sleep(10) // NOTE: This happens LAST because this is where

	to_chat(owner, "<span class='warning'>DEBUG: handle_life() [owner] is no longer bloodsucker! </span>")

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			BLOOD

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Overwrites handle_blood in blood.dm
/datum/antagonist/bloodsucker/proc/handle_blood()
	// Originals:
	// /mob/living/carbon/proc/handle_blood() in life.dm
	// /mob/living/carbon/human/handle_blood() in blood.dm

	// TORPOR: Cancel here! Don't heal or prevent bleeding.  IN FACT, maybe the handle_blood() check in life.dm can happen AS NORMAL if we return 0 here. That way you can
	//		   still bleed out if wounded, and otherwise appear normal.
	if (owner.current.stat == DEAD)
		return

	if (!poweron_humandisguise)
		// Regenerate
		handle_healing_natural()

	// Tick Down Blood
	//if (!feedTarget) // If not feeding
	set_blood_volume (-0.05) // (-0.3) // Default normal is 560. Also, humans REGROW blood at 0.1 a tick. Never go lower than BLOOD_VOLUME_BAD
	// NOTE: Updated value since handle_blood occurs MUCH more often than in v1.0

	// Hunger, Frenzy, and Nutrition
	if (owner.current.stat == CONSCIOUS)
		handle_hunger_and_frenzy()

	// Death!
	//if (!user.getorganslot("heart"))
	//	user.stat = DEAD

	return 1

/datum/antagonist/bloodsucker/proc/set_blood_volume(value)
	// Default normal is 560. Also, humans REGROW blood at 0.1 a tick. Never go lower than BLOOD_VOLUME_BAD
	owner.current.blood_volume = Clamp(owner.current.blood_volume + value, 0, maxBloodVolume)
	update_hud()



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



datum/antagonist/bloodsucker/proc/handle_feed_blood(mob/living/carbon/target)

	// If we need info on Viruses in blood, Blood Types, etc. look up this in blood.dm:    transfer_blood_to()  /   get_blood_id()   /   get_blood_data()
	// NOTE: We don't use transfer_blood_to() because that's a DIRECT amount. Here, we want to sometimes TAKE 20 blood and GIVE 5 blood (dead target), for example.

	// Remove Blood from Victim
	var/blood_taken = feedAmount					// Starts at 20
	if (target.blood_volume >= blood_taken)
		target.blood_volume -= blood_taken
	else
		blood_taken = target.blood_volume
		target.blood_volume = 0

	// Store Nutrition
	var/nutrition_mult = 1
	var/satiety_mult = 0.2

	///////////

	// Shift Body Temp (toward Target's temp, by volume taken)
	owner.current.bodytemperature = ((owner.current.blood_volume * owner.current.bodytemperature) + (blood_taken * target.bodytemperature)) / (owner.current.blood_volume + blood_taken) // our volume * temp, + their volume * temp, / total volume
	// NOTE: natural_bodytemperature_stabilization in life.dm controls your body temp increase. Rather than alter those functions, why dont we STORE our current body temp and alter it every Tick?

	////////////

	// Reduce Value Quantity
	if (target.stat == DEAD)						// Penalty for Dead Blood
		blood_taken /= 4
		nutrition_mult = 0
		satiety_mult = 0
	if (!ishuman(target))							// Penalty for Non-Human Blood
		blood_taken /= 2
		nutrition_mult /= 2
		satiety_mult = 0

	////////////

	// Increase Blood Taken: Score
	bloodTakenLifetime += blood_taken
	// Advance my Blood Pool
	set_blood_volume(blood_taken)
	// Nutrition & Satiety
	owner.current.nutrition = min(NUTRITION_LEVEL_FULL, owner.current.nutrition + blood_taken * nutrition_mult)		//#define NUTRITION_LEVEL_FAT 600   #define NUTRITION_LEVEL_FULL 550   #define NUTRITION_LEVEL_WELL_FED 450   #define NUTRITION_LEVEL_FED 350   #define NUTRITION_LEVEL_HUNGRY 250   #define NUTRITION_LEVEL_STARVING 150
	owner.current.satiety += blood_taken * satiety_mult
	// Reagents
	if(target.reagents && target.reagents.total_volume)
		target.reagents.reaction(owner.current, INGEST, 1 / target.reagents.total_volume)
		target.reagents.trans_to(owner.current, 1)

	////////////

	// Non-Bloodsucker Drawbacks!
	if(!target.mind || !target.mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER))
		// More Heal while Feeding
		owner.current.heal_overall_damage(regenRate, regenRate) // Heal BRUTE / BURN
		// Continue Target Sleep
		target.Sleeping(50,0) 	 // SetSleeping() only changes sleep if the input is higher than the current value. AdjustSleeping() adds or subtracts //
		target.Unconscious(50,1) // SetUnconscious() only changes sleep if the input is higher than the current value. AdjustUnconscious() adds or subtracts //


	// Blood Gulp Sound
	owner.current.playsound_local(null, 'sound/effects/singlebeat.ogg', 40, 1) // Play THIS sound for user only. The "null" is where turf would go if a location was needed. Null puts it right in their head.




/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			HEALING

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

datum/antagonist/bloodsucker/proc/handle_healing_natural(healmult=1) // Return TRUE if we just healed wounds. Return FALSE if we don't have any.

	// No healing if your powers are disabled (no heart)
	if (!owner.current.BloodsuckerCanUsePowers())
		return 1

	// No bleeding & No Trails // Taken from human_defines.dm
	if (ishuman(owner.current))
		var/mob/living/carbon/human/H = owner.current
		H.bleed_rate = 0

	// Stamina/Clone/Brain damage heal quickly as a Vamp, regardless of Blood.
	owner.current.adjustStaminaLoss(-5, 0)
	owner.current.adjustCloneLoss(-1 * healmult, 0)
	owner.current.adjustBrainLoss(-1 * healmult, 0)
	owner.current.AdjustStun(-5, 0)
	owner.current.AdjustUnconscious(-5, TRUE)

	// We ONLY heal if we have blood remaining.
	if (owner.current.blood_volume <= 0)
		return 1	// We return TRUE because we're not done healing.

	// Do I have damage to ANY bodypart?
	var/mob/living/carbon/C = owner.current
	if (C.getBruteLoss() + C.getFireLoss() > 0)//C.get_damaged_bodyparts(TRUE, TRUE))
		// We have damage. Let's heal (one time)
		C.heal_overall_damage(regenRate * healmult, 0.1 * healmult) 	// Heal BRUTE / BURN in random portions throughout the body.
		set_blood_volume(-regenRate * healmult)							// Costs blood to heal.
		// DONE! After healing, we stop here.
		return 1

	// No normal wounds remaining!
	return 0

datum/antagonist/bloodsucker/proc/handle_healing_torpid() // Return TRUE if we just healed wounds. Return FALSE if we don't have any.

	// No healing if your powers are disabled (no heart)
	if (!owner.current.BloodsuckerCanUsePowers())
		return 1

	// Toxins, Oxygen (Torpid vamps still heal this)
	owner.current.setOxyLoss(0)
	owner.current.setToxLoss(0)

	// Missing Limbs
	var/list/missing = owner.current.get_missing_limbs()
	if (missing.len)
		// 1) Find ONE Limb and regenerate it.
		var/targetLimb = pick(missing)
		owner.current.regenerate_limb(targetLimb, 0)		// regenerate_limbs() <--- If you want to EXCLUDE certain parts, do it like this ----> regenerate_limbs(0, list("head"))
		// 2) Limb returns Damaged
		var/obj/item/bodypart/L = owner.current.get_bodypart( targetLimb )
		L.brute_dam = 50
		to_chat(owner.current, "<span class='notice'>Your flesh knits as it regrows [L]!</span>")
		playsound(owner.current, 'sound/magic/demon_consume.ogg', 50, 1)
		// DONE! After regenerating a limb, we stop here.
		return 1

	//user.regenerate_organs()
	//H.remove_all_embedded_objects()

	// Nothing left to heal! ALL DONE!
	return 0






/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			HUMAN FOOD

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

mob/proc/CheckBloodsuckerEatFood(var/food_nutrition)
	if (!isliving(src))
		return
	var/mob/living/L = src
	if (!L.AmBloodsucker())
		return
	// We're a vamp? Try to eat food...
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = mind.has_antag_datum(ANTAG_DATUM_BLOODSUCKER)
	bloodsuckerdatum.handle_eat_human_food(food_nutrition)


datum/antagonist/bloodsucker/proc/handle_eat_human_food(var/food_nutrition) // Called from snacks.dm and drinks.dm
	to_chat(owner, "<span class='warning'>DEBUG: handle_eat_human_food() [owner.current]</span>")

	if (!owner.current || !iscarbon(owner.current))
		return
	var/mob/living/carbon/C = owner.current

	// Remove Nutrition, Give Bad Food
	C.nutrition -= food_nutrition
	badfood += food_nutrition

	// Already ate some bad clams? Then we can back out, because we're already sick from it.
	if (badfood != food_nutrition)
		return
	// Haven't eaten, but I'm in a Human Disguise.
	else if (poweron_humandisguise)
		to_chat(C, "<span class='notice'>Your stomach turns, but your Human Disguise keeps the food down...for now.</span>")

	// First Food

	// Keep looping until we purge. If we have activated our Human Disguise, we ignore the food. But it'll come up eventually...
	var/sickphase = 0
	while (badfood)

		// Wait an interval...
		sleep(100 + 50 * sickphase) // At intervals of 100, 150, and 200. (10 seconds, 15 seconds, and 20 seconds)

		// Died? Cancel
		if (C.stat == DEAD)
			return
		// Put up disguise? Then hold off the vomit.
		if (poweron_humandisguise)
			if (sickphase > 0)
				to_chat(C, "<span class='notice'>Your stomach settles temporarily. You regain your composure...for now.</span>")
			sickphase = 0
			continue

		switch(sickphase)
			if (1)
				to_chat(C, "<span class='warning'>You feel unwell. You can taste ash on your tongue.</span>")
			if (2)
				to_chat(C, "<span class='warning'>Your stomach turns. Whatever you ate tastes of grave dirt and brimstone.</span>")
				C.Dizzy(15)
			if (3)
				to_chat(C, "<span class='warning'>You purge the food of the living from your viscera! You've never felt worse.</span>")
				C.vomit(badfood * 4, badfood * 2, 0)  // (var/lost_nutrition = 10, var/blood = 0, var/stun = 1, var/distance = 0, var/message = 1, var/toxic = 0)
				C.blood_volume = max(0, C.blood_volume - badfood * 2)
				C.Stun(rand(2,3))
				C.Dizzy(10)
				badfood = 0

		sickphase ++