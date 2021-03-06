/datum/saymode
	var/key
	var/mode

//Return FALSE if you have handled the message. Otherwise, return TRUE and saycode will continue doing saycode things.
//user = whoever said the message
//message = the message
//language = the language.
/datum/saymode/proc/handle_message(mob/living/user, message, datum/language/language)
	return TRUE


/datum/saymode/changeling
	key = "g"
	mode = MODE_CHANGELING

/datum/saymode/changeling/handle_message(mob/living/user, message, datum/language/language)
	switch(user.lingcheck())
		if(LINGHIVE_LINK)
			var/msg = "<i><font color=#800040><b>[user.mind]:</b> [message]</font></i>"
			for(var/_M in GLOB.mob_list)
				var/mob/M = _M
				if(M in GLOB.dead_mob_list)
					var/link = FOLLOW_LINK(M, user)
					to_chat(M, "[link] [msg]")
				else
					switch(M.lingcheck())
						if(LINGHIVE_LINK, LINGHIVE_LING)
							to_chat(M, msg)
						if(LINGHIVE_OUTSIDER)
							if(prob(40))
								to_chat(M, "<i><font color=#800080>We can faintly sense an outsider trying to communicate through the hivemind...</font></i>")
		if(LINGHIVE_LING)
			var/datum/antagonist/changeling/changeling = user.mind.has_antag_datum(/datum/antagonist/changeling)
			var/msg = "<i><font color=#800080><b>[changeling.changelingID]:</b> [message]</font></i>"
			log_talk(src,"[changeling.changelingID]/[user.key] : [message]",LOGSAY)
			for(var/_M in GLOB.mob_list)
				var/mob/M = _M
				if(M in GLOB.dead_mob_list)
					var/link = FOLLOW_LINK(M, user)
					to_chat(M, "[link] [msg]")
				else
					switch(M.lingcheck())
						if(LINGHIVE_LINK)
							to_chat(M, msg)
						if(LINGHIVE_LING)
							to_chat(M, msg)
						if(LINGHIVE_OUTSIDER)
							if(prob(40))
								to_chat(M, "<i><font color=#800080>We can faintly sense another of our kind trying to communicate through the hivemind...</font></i>")
		if(LINGHIVE_OUTSIDER)
			to_chat(user, "<i><font color=#800080>Our senses have not evolved enough to be able to communicate this way...</font></i>")
	return FALSE


/datum/saymode/xeno
	key = "a"
	mode = MODE_ALIEN

/datum/saymode/xeno/handle_message(mob/living/user, message, datum/language/language)
	if(user.hivecheck())
		user.alien_talk(message)
	return FALSE


/datum/saymode/vocalcords
	key = "x"
	mode = MODE_VOCALCORDS

/datum/saymode/vocalcords/handle_message(mob/living/user, message, datum/language/language)
	if(iscarbon(user))
		var/mob/living/carbon/C = user
		var/obj/item/organ/vocal_cords/V = C.getorganslot(ORGAN_SLOT_VOICE)
		if(V && V.can_speak_with())
			V.handle_speech(message) //message
			V.speak_with(message) //action
	return FALSE


/datum/saymode/binary //everything that uses .b (silicons, drones, blobbernauts/spores, swarmers)
	key = "b"
	mode = MODE_BINARY

/datum/saymode/binary/handle_message(mob/living/user, message, datum/language/language)
	if(isswarmer(user))
		var/mob/living/simple_animal/hostile/swarmer/S = user
		S.swarmer_chat(message)
		return FALSE
	if(isblobmonster(user))
		var/mob/living/simple_animal/hostile/blob/B = user
		B.blob_chat(message)
		return FALSE
	if(isdrone(user))
		var/mob/living/simple_animal/drone/D = user
		D.drone_chat(message)
		return FALSE
	if(user.binarycheck())
		user.robot_talk(message)
		return FALSE
	return FALSE


/datum/saymode/holopad
	key = "h"
	mode = MODE_HOLOPAD

/datum/saymode/holopad/handle_message(mob/living/user, message, datum/language/language)
	if(isAI(user))
		var/mob/living/silicon/ai/AI = user
		AI.holopad_talk(message, language)
		return FALSE
	return TRUE
