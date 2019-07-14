/mob/living/carbon/human
	name = "unknown"
	real_name = "unknown"
	voice_name = "unknown"
	icon = 'icons/mob/human.dmi'
	icon_state = "body_m_s"
	directional_lum = 1 //humans carrying light sources only illuminate the area in front of themselves
	hud_possible = list(HEALTH_HUD,STATUS_HUD, STATUS_HUD_OOC, STATUS_HUD_XENO_INFECTION,ID_HUD,WANTED_HUD,IMPLOYAL_HUD,IMPCHEM_HUD,IMPTRACK_HUD, SPECIALROLE_HUD, SQUAD_HUD)
	var/embedded_flag	  //To check if we've need to roll for damage on movement while an item is imbedded in us.
	var/regenZ = 1 //Temp zombie thing until I write a better method ~Apop
	var/allow_gun_usage = FALSE //False by default, so that synthetics can't use guns.
	var/has_used_pamphlet = FALSE //Has this person used a pamphlet?

/mob/living/carbon/human/New(var/new_loc, var/new_species = null)
	blood_type = pick(7;"O-", 38;"O+", 6;"A-", 34;"A+", 2;"B-", 9;"B+", 1;"AB-", 3;"AB+")

	human_mob_list += src
	living_human_list += src

	if(!species)
		if(new_species)
			set_species(new_species)
		else
			set_species()

	var/datum/reagents/R = new/datum/reagents(1000)
	reagents = R
	R.my_atom = src

	..()

	round_statistics.total_humans_created++
	prev_gender = gender // Debug for plural genders

/mob/living/carbon/human/prepare_huds()
	..()
	//updating all the mob's hud images
	med_hud_set_health()
	med_hud_set_armor()
	med_hud_set_status()
	sec_hud_set_ID()
	sec_hud_set_implants()
	sec_hud_set_security_status()
	hud_set_squad()
	//and display them
	add_to_all_mob_huds()


/mob/living/carbon/human/Dispose()
	if(assigned_squad)
		var/n = assigned_squad.marines_list.Find(src)
		if(n)
			assigned_squad.marines_list[n] = name //mob reference replaced by name string
		if(assigned_squad.squad_leader == src)
			assigned_squad.squad_leader = null
		assigned_squad = null
	remove_from_all_mob_huds()
	human_mob_list -= src
	living_human_list -= src
	. = ..()

/mob/living/carbon/human/Stat()
	if (!..())
		return 0

	if (statpanel("Stats"))
		stat("Operation Time:","[worldtime2text()]")
		stat("Security Level:","[uppertext(get_security_level())]")

		if(ticker && ticker.mode && ticker.mode.active_lz)
			stat("Primary LZ: ", ticker.mode.active_lz.loc.loc.name)

		if(assigned_squad)
			if(assigned_squad.overwatch_officer)
				stat("Overwatch Officer: ", "[assigned_squad.overwatch_officer.get_paygrade()][assigned_squad.overwatch_officer.name]")
			if(assigned_squad.primary_objective)
				stat("Primary Objective: ", assigned_squad.primary_objective)
			if(assigned_squad.secondary_objective)
				stat("Secondary Objective: ", assigned_squad.secondary_objective)

		if(mobility_aura)
			stat("Active Order: ", "MOVE")
		if(protection_aura)
			stat("Active Order: ", "HOLD")
		if(marskman_aura)
			stat("Active Order: ", "FOCUS")

		if(EvacuationAuthority)
			var/eta_status = EvacuationAuthority.get_status_panel_eta()
			if(eta_status)
				stat(null, eta_status)
		return 1

/mob/living/carbon/human/ex_act(severity, direction)

	if(lying)
		severity *= EXPLOSION_PRONE_MULTIPLIER

	if(severity >= 30)
		flash_eyes()

	var/b_loss = 0
	var/f_loss = 0

	var/damage = severity

	damage = armor_damage_reduction(config.marine_explosive, damage, getarmor(null, ARMOR_BOMB))

	if (damage >= EXPLOSION_THRESHOLD_GIB)
		gib()
		return

	if(!istype(wear_ear, /obj/item/clothing/ears/earmuffs))
		ear_damage += severity * 0.15
		ear_deaf += severity * 0.5

	var/knockdown_value = min( round( severity*0.1  ,1) ,10)
	if(knockdown_value > 0)
		var/obj/item/Item1 = get_active_hand()
		var/obj/item/Item2 = get_inactive_hand()
		KnockDown(knockdown_value)
		var/knockout_value = min( round( damage*0.1  ,1) ,10)
		KnockOut( knockout_value )
		Daze( knockout_value*2 )
		explosion_throw(severity, direction)

		if(Item1 && isturf(Item1.loc))
			Item1.explosion_throw(severity, direction)
		if(Item2 && isturf(Item2.loc))
			Item2.explosion_throw(severity, direction)

	if (damage >= 0)
		b_loss += damage * 0.5
		f_loss += damage * 0.5
	else
		return

	var/update = 0

	//Focus half the blast on one organ
	var/datum/limb/take_blast = pick(limbs)
	update |= take_blast.take_damage(b_loss * 0.5, f_loss * 0.5, used_weapon = "Explosive blast")

	//Distribute the remaining half all limbs equally
	b_loss *= 0.5
	f_loss *= 0.5

	var/weapon_message = "Explosive Blast"

	for(var/datum/limb/temp in limbs)
		switch(temp.name)
			if("head")
				update |= temp.take_damage(b_loss * 0.2, f_loss * 0.2, used_weapon = weapon_message)
			if("chest")
				update |= temp.take_damage(b_loss * 0.4, f_loss * 0.4, used_weapon = weapon_message)
			if("l_arm")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("r_arm")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("l_leg")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("r_leg")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("r_foot")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("l_foot")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("r_arm")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
			if("l_arm")
				update |= temp.take_damage(b_loss * 0.05, f_loss * 0.05, used_weapon = weapon_message)
	if(update)	UpdateDamageIcon()
	return 1


/mob/living/carbon/human/attack_animal(mob/living/M as mob)
	if(M.melee_damage_upper == 0)
		M.emote("[M.friendly] [src]")
	else
		if(M.attack_sound)
			playsound(loc, M.attack_sound, 25, 1)
		for(var/mob/O in viewers(src, null))
			O.show_message(SPAN_DANGER("<B>[M]</B> [M.attacktext] [src]!"), 1)
		M.attack_log += text("\[[time_stamp()]\] <font color='red'>attacked [src.name] ([src.ckey])</font>")
		src.attack_log += text("\[[time_stamp()]\] <font color='orange'>was attacked by [M.name] ([M.ckey])</font>")
		var/damage = rand(M.melee_damage_lower, M.melee_damage_upper)
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/datum/limb/affecting = get_limb(ran_zone(dam_zone))
		var/armor = run_armor_check(affecting, ARMOR_MELEE)
		apply_damage(damage, BRUTE, affecting, armor)
		if(armor >= 2)	return


/mob/living/carbon/human/proc/implant_loyalty(mob/living/carbon/human/M, override = FALSE) // Won't override by default.
	if(!config.use_loyalty_implants && !override) return // Nuh-uh.

	var/obj/item/implant/loyalty/L = new/obj/item/implant/loyalty(M)
	L.imp_in = M
	L.implanted = 1
	var/datum/limb/affected = M.get_limb("head")
	affected.implants += L
	L.part = affected

/mob/living/carbon/human/proc/is_loyalty_implanted(mob/living/carbon/human/M)
	for(var/L in M.contents)
		if(istype(L, /obj/item/implant/loyalty))
			for(var/datum/limb/O in M.limbs)
				if(L in O.implants)
					return 1
	return 0



/mob/living/carbon/human/show_inv(mob/living/user)
	if(ismaintdrone(user))
		return
	var/obj/item/clothing/under/suit = null
	if (istype(w_uniform, /obj/item/clothing/under))
		suit = w_uniform

	user.set_interaction(src)
	var/dat = {"
	<B><HR><FONT size=3>[name]</FONT></B>
	<BR><HR>
	<BR><B>Head(Mask):</B> <A href='?src=\ref[src];item=[WEAR_FACE]'>[(wear_mask ? wear_mask : "Nothing")]</A>
	<BR><B>Left Hand:</B> <A href='?src=\ref[src];item=[WEAR_L_HAND]'>[(l_hand ? l_hand  : "Nothing")]</A>
	<BR><B>Right Hand:</B> <A href='?src=\ref[src];item=[WEAR_R_HAND]'>[(r_hand ? r_hand : "Nothing")]</A>
	<BR><B>Gloves:</B> <A href='?src=\ref[src];item=[WEAR_HANDS]'>[(gloves ? gloves : "Nothing")]</A>
	<BR><B>Eyes:</B> <A href='?src=\ref[src];item=[WEAR_EYES]'>[(glasses ? glasses : "Nothing")]</A>
	<BR><B>Left Ear:</B> <A href='?src=\ref[src];item=[WEAR_EAR]'>[(wear_ear ? wear_ear : "Nothing")]</A>
	<BR><B>Head:</B> <A href='?src=\ref[src];item=[WEAR_HEAD]'>[(head ? head : "Nothing")]</A>
	<BR><B>Shoes:</B> <A href='?src=\ref[src];item=[WEAR_FEET]'>[(shoes ? shoes : "Nothing")]</A>
	<BR><B>Belt:</B> <A href='?src=\ref[src];item=[WEAR_WAIST]'>[(belt ? belt : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(belt, /obj/item/tank) && !internal) ? " <A href='?src=\ref[src];internal=1'>Set Internal</A>" : "")]
	<BR><B>Uniform:</B> <A href='?src=\ref[src];item=[WEAR_BODY]'>[(w_uniform ? w_uniform : "Nothing")]</A> [(suit) ? ((suit.has_sensor == 1) ? " <A href='?src=\ref[src];sensor=1'>Sensors</A>" : "") : null]
	<BR><B>(Exo)Suit:</B> <A href='?src=\ref[src];item=[WEAR_JACKET]'>[(wear_suit ? wear_suit : "Nothing")]</A>
	<BR><B>Back:</B> <A href='?src=\ref[src];item=[WEAR_BACK]'>[(back ? back : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(back, /obj/item/tank) && !( internal )) ? " <A href='?src=\ref[src];internal=1'>Set Internal</A>" : "")]
	<BR><B>ID:</B> <A href='?src=\ref[src];item=[WEAR_ID]'>[(wear_id ? wear_id : "Nothing")]</A>
	<BR><B>Suit Storage:</B> <A href='?src=\ref[src];item=[WEAR_J_STORE]'>[(s_store ? s_store : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(s_store, /obj/item/tank) && !( internal )) ? " <A href='?src=\ref[src];internal=1'>Set Internal</A>" : "")]
	<BR><B>Left Pocket:</B> <A href='?src=\ref[src];item=[WEAR_L_STORE]'>[(l_store ? l_store : "Nothing")]</A>
	<BR><B>Right Pocket:</B> <A href='?src=\ref[src];item=[WEAR_R_STORE]'>[(r_store ? r_store : "Nothing")]</A>
	<BR>
	[handcuffed ? "<BR><A href='?src=\ref[src];item=[WEAR_HANDCUFFS]'>Handcuffed</A>" : ""]
	[legcuffed ? "<BR><A href='?src=\ref[src];item=[WEAR_LEGCUFFS]'>Legcuffed</A>" : ""]
	[suit && suit.accessories.len ? "<BR><A href='?src=\ref[src];tie=1'>Remove Accessory</A>" : ""]
	[internal ? "<BR><A href='?src=\ref[src];internal=1'>Remove Internal</A>" : ""]
	[istype(wear_id, /obj/item/card/id/dogtag) ? "<BR><A href='?src=\ref[src];item=id'>Retrieve Info Tag</A>" : ""]
	<BR><A href='?src=\ref[src];splints=1'>Remove Splints</A>
	<BR>
	<BR><A href='?src=\ref[user];refresh=1'>Refresh</A>
	<BR><A href='?src=\ref[user];mach_close=mob[name]'>Close</A>
	<BR>"}
	user << browse(dat, "window=mob[name];size=380x540")
	onclose(user, "mob[name]")
	return

// called when something steps onto a human
// this handles mulebots and vehicles
/mob/living/carbon/human/Crossed(var/atom/movable/AM)
	if(istype(AM, /obj/machinery/bot/mulebot))
		var/obj/machinery/bot/mulebot/MB = AM
		MB.RunOver(src)

	if(istype(AM, /obj/vehicle))
		var/obj/vehicle/V = AM
		V.RunOver(src)


//gets assignment from ID or ID inside PDA or PDA itself
//Useful when player do something with computers
/mob/living/carbon/human/proc/get_assignment(var/if_no_id = "No id", var/if_no_job = "No job")
	var/obj/item/device/pda/pda = wear_id
	var/obj/item/card/id/id = wear_id
	if (istype(pda))
		if (pda.id && istype(pda.id, /obj/item/card/id))
			. = pda.id.assignment
		else
			. = pda.ownjob
	else if (istype(id))
		. = id.assignment
	else
		return if_no_id
	if (!.)
		. = if_no_job
	return

//gets name from ID or ID inside PDA or PDA itself
//Useful when player do something with computers
/mob/living/carbon/human/proc/get_authentification_name(var/if_no_id = "Unknown")
	var/obj/item/device/pda/pda = wear_id
	var/obj/item/card/id/id = wear_id
	if (istype(pda))
		if (pda.id)
			. = pda.id.registered_name
		else
			. = pda.owner
	else if (istype(id))
		. = id.registered_name
	else
		return if_no_id
	return

//gets paygrade from ID
//paygrade is a user's actual rank, as defined on their ID.  size 1 returns an abbreviation, size 0 returns the full rank name, the third input is used to override what is returned if no paygrade is assigned.
/mob/living/carbon/human/proc/get_paygrade(size = 1)
	switch(species.name)
		if("Human","Human Hero")
			var/obj/item/card/id/id = wear_id
			if(istype(id)) . = get_paygrades(id.paygrade, size, gender)
			else return ""
		else return ""

//repurposed proc. Now it combines get_id_name() and get_face_name() to determine a mob's name variable. Made into a seperate proc as it'll be useful elsewhere
/mob/living/carbon/human/proc/get_visible_name()
	if( wear_mask && (wear_mask.flags_inv_hide & HIDEFACE) )	//Wearing a mask which hides our face, use id-name if possible
		return get_id_name("Unknown")
	if( head && (head.flags_inv_hide & HIDEFACE) )
		return get_id_name("Unknown")		//Likewise for hats
	var/face_name = get_face_name()
	var/id_name = get_id_name("")
	if(id_name && (id_name != face_name))
		return "[face_name] (as [id_name])"
	return face_name

//Returns "Unknown" if facially disfigured and real_name if not. Useful for setting name when polyacided or when updating a human's name variable
/mob/living/carbon/human/proc/get_face_name()
	var/datum/limb/head/head = get_limb("head")
	if( !head || head.disfigured || (head.status & LIMB_DESTROYED) || !real_name || (HUSK in mutations) )	//disfigured. use id-name if possible
		return "Unknown"
	return real_name

//gets name from ID or PDA itself, ID inside PDA doesn't matter
//Useful when player is being seen by other mobs
/mob/living/carbon/human/proc/get_id_name(var/if_no_id = "Unknown")
	. = if_no_id
	if(istype(wear_id,/obj/item/device/pda))
		var/obj/item/device/pda/P = wear_id
		return P.owner
	if(wear_id)
		var/obj/item/card/id/I = wear_id.GetID()
		if(I)
			return I.registered_name
	return

//gets ID card object from special clothes slot or null.
/mob/living/carbon/human/proc/get_idcard()
	if(wear_id)
		return wear_id.GetID()

//Removed the horrible safety parameter. It was only being used by ninja code anyways.
//Now checks siemens_coefficient of the affected area by default
/mob/living/carbon/human/electrocute_act(var/shock_damage, var/obj/source, var/base_siemens_coeff = 1.0, var/def_zone = null)
	if(status_flags & GODMODE)	return 0	//godmode

	if (!def_zone)
		def_zone = pick("l_hand", "r_hand")

	var/datum/limb/affected_organ = get_limb(check_zone(def_zone))
	var/siemens_coeff = base_siemens_coeff * get_siemens_coefficient_organ(affected_organ)

	return ..(shock_damage, source, siemens_coeff, def_zone)


/mob/living/carbon/human/Topic(href, href_list)
	if (href_list["refresh"])
		if(interactee&&(in_range(src, usr)))
			show_inv(interactee)

	if (href_list["mach_close"])
		var/t1 = text("window=[]", href_list["mach_close"])
		unset_interaction()
		src << browse(null, t1)


	if (href_list["item"])
		if(!usr.is_mob_incapacitated() && Adjacent(usr))
			if(href_list["item"] == "id")
				if(istype(wear_id, /obj/item/card/id/dogtag))
					var/obj/item/card/id/dogtag/DT = wear_id
					if(!DT.dogtag_taken)
						if(stat == DEAD)
							to_chat(usr, SPAN_NOTICE("You take [src]'s information tag, leaving the ID tag"))
							DT.dogtag_taken = TRUE
							DT.icon_state = "dogtag_taken"
							var/obj/item/dogtag/D = new(loc)
							D.fallen_names = list(DT.registered_name)
							D.fallen_assgns = list(DT.assignment)
							D.fallen_blood_types = list(DT.blood_type)
							usr.put_in_hands(D)
						else
							to_chat(usr, SPAN_WARNING("You can't take a dogtag's information tag while its owner is alive."))
					else
						to_chat(usr, SPAN_WARNING("Someone's already taken [src]'s information tag."))
					return
			//police skill lets you strip multiple items from someone at once.
			if(!usr.action_busy || (!usr.mind || !usr.mind.cm_skills || usr.mind.cm_skills.police >= SKILL_POLICE_MP))
				var/slot = href_list["item"]
				var/obj/item/what = get_item_by_slot(slot)
				if(what)
					usr.stripPanelUnequip(what,src,slot)
				else
					what = usr.get_active_hand()
					usr.stripPanelEquip(what,src,slot)

	if(href_list["internal"])

		if(!usr.action_busy)
			attack_log += text("\[[time_stamp()]\] <font color='orange'>Has had their internals toggled by [usr.name] ([usr.ckey])</font>")
			usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Attempted to toggle [name]'s ([ckey]) internals</font>")
			if(internal)
				usr.visible_message(SPAN_DANGER("<B>[usr] is trying to disable [src]'s internals</B>"), null, null, 3)
			else
				usr.visible_message(SPAN_DANGER("<B>[usr] is trying to enable [src]'s internals.</B>"), null, null, 3)

			if(do_after(usr, POCKET_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, src, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
				if (internal)
					internal.add_fingerprint(usr)
					internal = null
					if (hud_used && hud_used.internals)
						hud_used.internals.icon_state = "internal0"
					visible_message("[src] is no longer running on internals.", null, null, 1)
				else
					if(istype(wear_mask, /obj/item/clothing/mask))
						if (istype(back, /obj/item/tank))
							internal = back
						else if (istype(s_store, /obj/item/tank))
							internal = s_store
						else if (istype(belt, /obj/item/tank))
							internal = belt
						if (internal)
							visible_message(SPAN_NOTICE("[src] is now running on internals."), null, null, 1)
							internal.add_fingerprint(usr)
							if (hud_used && hud_used.internals)
								hud_used.internals.icon_state = "internal1"

				// Update strip window
				if(usr.interactee == src && Adjacent(usr))
					show_inv(usr)


	if(href_list["splints"])
		remove_splints(usr)

	if(href_list["tie"])
		if(!usr.action_busy)
			if(w_uniform && istype(w_uniform, /obj/item/clothing))
				var/obj/item/clothing/under/U = w_uniform
				var/obj/item/clothing/accessory/A = U.accessories[1]
				if(U.accessories.len > 1)
					A = input("Select an accessory to remove from [U]") as null|anything in U.accessories
				if(!istype(A))
					return
				attack_log += text("\[[time_stamp()]\] <font color='orange'>Has had their accessory ([A]) removed by [usr.name] ([usr.ckey])</font>")
				usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Attempted to remove [name]'s ([ckey]) accessory ([A])</font>")
				if(istype(A, /obj/item/clothing/accessory/holobadge) || istype(A, /obj/item/clothing/accessory/medal))
					visible_message(SPAN_DANGER("<B>[usr] tears off \the [A] from [src]'s [U]!</B>"), null, null, 5)
					if(U == w_uniform)
						U.remove_accessory(usr, A)
				else
					visible_message(SPAN_DANGER("<B>[usr] is trying to take off \a [A] from [src]'s [U]!</B>"), null, null, 5)
					if(do_after(usr, HUMAN_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, src, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
						if(U == w_uniform)
							U.remove_accessory(usr, A)

	if(href_list["sensor"])
		if(!usr.action_busy)

			attack_log += text("\[[time_stamp()]\] <font color='orange'>Has had their sensors toggled by [usr.name] ([usr.ckey])</font>")
			usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Attempted to toggle [name]'s ([ckey]) sensors</font>")
			var/obj/item/clothing/under/U = w_uniform
			if(U.has_sensor >= 2)
				to_chat(usr, "The controls are locked.")
			else
				var/oldsens = U.has_sensor
				visible_message(SPAN_DANGER("<B>[usr] is trying to modify [src]'s sensors!</B>"), null, null, 4)
				if(do_after(usr, HUMAN_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, src, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
					if(U == w_uniform)
						if(U.has_sensor >= 2)
							to_chat(usr, "The controls are locked.")
						else if(U.has_sensor == oldsens)
							U.set_sensors(usr)


	if (href_list["squadfireteam"])
		if(!usr.is_mob_incapacitated() && get_dist(usr, src) <= 7 && hasHUD(usr,"squadleader"))
			var/mob/living/carbon/human/H = usr
			if(mind)
				var/obj/item/card/id/ID = get_idcard()
				if(ID && (ID.rank in ROLES_MARINES))//still a marine, with an ID.
					if(assigned_squad == H.assigned_squad) //still same squad
						var/newfireteam = input(usr, "Assign this marine to a fireteam.", "Fire Team Assignment") as null|anything in list("None", "Fire Team 1", "Fire Team 2", "Fire Team 3")
						if(H.is_mob_incapacitated() || get_dist(H, src) > 7 || !hasHUD(H,"squadleader")) return
						ID = get_idcard()
						if(ID && ID.rank in ROLES_MARINES)//still a marine with an ID
							if(assigned_squad == H.assigned_squad) //still same squad
								switch(newfireteam)
									if("None") ID.assigned_fireteam = 0
									if("Fire Team 1") ID.assigned_fireteam = 1
									if("Fire Team 2") ID.assigned_fireteam = 2
									if("Fire Team 3") ID.assigned_fireteam = 3
									else return
								hud_set_squad()


	if (href_list["criminal"])
		if(hasHUD(usr,"security"))

			var/modified = 0
			var/perpname = "wot"
			if(wear_id)
				var/obj/item/card/id/I = wear_id.GetID()
				if(I)
					perpname = I.registered_name
				else
					perpname = name
			else
				perpname = name

			if(perpname)
				for (var/datum/data/record/E in data_core.general)
					if (E.fields["name"] == perpname)
						for (var/datum/data/record/R in data_core.security)
							if (R.fields["id"] == E.fields["id"])

								var/setcriminal = input(usr, "Specify a new criminal status for this person.", "Security HUD", R.fields["criminal"]) in list("None", "*Arrest*", "Incarcerated", "Released", "Cancel")

								if(hasHUD(usr, "security"))
									if(setcriminal != "Cancel")
										R.fields["criminal"] = setcriminal
										modified = 1
										sec_hud_set_security_status()


			if(!modified)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if (href_list["secrecord"])
		if(hasHUD(usr,"security"))
			var/perpname = "wot"
			var/read = 0

			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name
			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.security)
						if (R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"security"))
								to_chat(usr, "<b>Name:</b> [R.fields["name"]]	<b>Criminal Status:</b> [R.fields["criminal"]]")
								to_chat(usr, "<b>Minor Crimes:</b> [R.fields["mi_crim"]]")
								to_chat(usr, "<b>Details:</b> [R.fields["mi_crim_d"]]")
								to_chat(usr, "<b>Major Crimes:</b> [R.fields["ma_crim"]]")
								to_chat(usr, "<b>Details:</b> [R.fields["ma_crim_d"]]")
								to_chat(usr, "<b>Notes:</b> [R.fields["notes"]]")
								to_chat(usr, "<a href='?src=\ref[src];secrecordComment=`'>\[View Comment Log\]</a>")
								read = 1

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if (href_list["secrecordComment"])
		if(hasHUD(usr,"security"))
			var/perpname = "wot"
			var/read = 0

			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name
			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.security)
						if (R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"security"))
								read = 1
								var/counter = 1
								while(R.fields[text("com_[]", counter)])
									usr << text("[]", R.fields[text("com_[]", counter)])
									counter++
								if (counter == 1)
									to_chat(usr, "No comment found")
								to_chat(usr, "<a href='?src=\ref[src];secrecordadd=`'>\[Add comment\]</a>")

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if (href_list["secrecordadd"])
		if(hasHUD(usr,"security"))
			var/perpname = "wot"
			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name
			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.security)
						if (R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"security"))
								var/t1 = copytext(sanitize(input("Add Comment:", "Sec. records", null, null)  as message),1,MAX_MESSAGE_LEN)
								if ( !(t1) || usr.stat || usr.is_mob_restrained() || !(hasHUD(usr,"security")) )
									return
								var/counter = 1
								while(R.fields[text("com_[]", counter)])
									counter++
								if(istype(usr,/mob/living/carbon/human))
									var/mob/living/carbon/human/U = usr
									R.fields[text("com_[counter]")] = text("Made by [U.get_authentification_name()] ([U.get_assignment()]) on [time2text(world.realtime, "DDD MMM DD hh:mm:ss")], [game_year]<BR>[t1]")
								if(istype(usr,/mob/living/silicon/robot))
									var/mob/living/silicon/robot/U = usr
									R.fields[text("com_[counter]")] = text("Made by [U.name] ([U.modtype] [U.braintype]) on [time2text(world.realtime, "DDD MMM DD hh:mm:ss")], [game_year]<BR>[t1]")

	if (href_list["medical"])
		if(hasHUD(usr,"medical"))
			var/perpname = "wot"
			var/modified = 0

			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name

			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.general)
						if (R.fields["id"] == E.fields["id"])

							var/setmedical = input(usr, "Specify a new medical status for this person.", "Medical HUD", R.fields["p_stat"]) in list("*SSD*", "*Deceased*", "Physically Unfit", "Active", "Disabled", "Cancel")

							if(hasHUD(usr,"medical"))
								if(setmedical != "Cancel")
									R.fields["p_stat"] = setmedical
									modified = 1
									if(PDA_Manifest.len)
										PDA_Manifest.Cut()

									spawn()
										if(istype(usr,/mob/living/carbon/human))
											var/mob/living/carbon/human/U = usr
											U.handle_regular_hud_updates()
										if(istype(usr,/mob/living/silicon/robot))
											var/mob/living/silicon/robot/U = usr
											U.handle_regular_hud_updates()

			if(!modified)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if (href_list["medrecord"])
		if(hasHUD(usr,"medical"))
			var/perpname = "wot"
			var/read = 0

			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name
			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.medical)
						if (R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"medical"))
								to_chat(usr, "<b>Name:</b> [R.fields["name"]]	<b>Blood Type:</b> [R.fields["b_type"]]")
								to_chat(usr, "<b>DNA:</b> [R.fields["b_dna"]]")
								to_chat(usr, "<b>Minor Disabilities:</b> [R.fields["mi_dis"]]")
								to_chat(usr, "<b>Details:</b> [R.fields["mi_dis_d"]]")
								to_chat(usr, "<b>Major Disabilities:</b> [R.fields["ma_dis"]]")
								to_chat(usr, "<b>Details:</b> [R.fields["ma_dis_d"]]")
								to_chat(usr, "<b>Notes:</b> [R.fields["notes"]]")
								to_chat(usr, "<a href='?src=\ref[src];medrecordComment=`'>\[View Comment Log\]</a>")
								read = 1

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if (href_list["medrecordComment"])
		if(hasHUD(usr,"medical"))
			var/perpname = "wot"
			var/read = 0

			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name
			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.medical)
						if (R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"medical"))
								read = 1
								var/counter = 1
								while(R.fields[text("com_[]", counter)])
									usr << text("[]", R.fields[text("com_[]", counter)])
									counter++
								if (counter == 1)
									to_chat(usr, "No comment found")
								to_chat(usr, "<a href='?src=\ref[src];medrecordadd=`'>\[Add comment\]</a>")

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if (href_list["medrecordadd"])
		if(hasHUD(usr,"medical"))
			var/perpname = "wot"
			if(wear_id)
				if(istype(wear_id,/obj/item/card/id))
					perpname = wear_id:registered_name
				else if(istype(wear_id,/obj/item/device/pda))
					var/obj/item/device/pda/tempPda = wear_id
					perpname = tempPda.owner
			else
				perpname = src.name
			for (var/datum/data/record/E in data_core.general)
				if (E.fields["name"] == perpname)
					for (var/datum/data/record/R in data_core.medical)
						if (R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"medical"))
								var/t1 = copytext(sanitize(input("Add Comment:", "Med. records", null, null)  as message),1,MAX_MESSAGE_LEN)
								if ( !(t1) || usr.stat || usr.is_mob_restrained() || !(hasHUD(usr,"medical")) )
									return
								var/counter = 1
								while(R.fields[text("com_[]", counter)])
									counter++
								if(istype(usr,/mob/living/carbon/human))
									var/mob/living/carbon/human/U = usr
									R.fields[text("com_[counter]")] = text("Made by [U.get_authentification_name()] ([U.get_assignment()]) on [time2text(world.realtime, "DDD MMM DD hh:mm:ss")], [game_year]<BR>[t1]")
								if(istype(usr,/mob/living/silicon/robot))
									var/mob/living/silicon/robot/U = usr
									R.fields[text("com_[counter]")] = text("Made by [U.name] ([U.modtype] [U.braintype]) on [time2text(world.realtime, "DDD MMM DD hh:mm:ss")], [game_year]<BR>[t1]")

	if (href_list["medholocard"])
		if(usr.mind && usr.mind.cm_skills && usr.mind.cm_skills.medical < SKILL_MEDICAL_MEDIC)
			to_chat(usr, SPAN_WARNING("You're not trained to use this."))
			return
		if(!has_species(src, "Human"))
			to_chat(usr, SPAN_WARNING("Triage holocards only works on humans."))
			return
		var/newcolor = input("Choose a triage holo card to add to the patient:", "Triage holo card", null, null) in list("black", "red", "orange", "none")
		if(!newcolor) return
		if(get_dist(usr, src) > 7)
			to_chat(usr, SPAN_WARNING("[src] is too far away."))
			return
		if(newcolor == "none")
			if(!holo_card_color) return
			holo_card_color = null
			to_chat(usr, SPAN_NOTICE("You remove the holo card on [src]."))
		else if(newcolor != holo_card_color)
			holo_card_color = newcolor
			to_chat(usr, SPAN_NOTICE("You add a [newcolor] holo card on [src]."))
		update_targeted()

	if (href_list["scanreport"])
		if(hasHUD(usr,"medical"))
			if(usr.mind && usr.mind.cm_skills && usr.mind.cm_skills.medical < SKILL_MEDICAL_MEDIC)
				to_chat(usr, SPAN_WARNING("You're not trained to use this."))
				return
			if(!has_species(src, "Human"))
				to_chat(usr, SPAN_WARNING("This only works on humans."))
				return
			if(get_dist(usr, src) > 7)
				to_chat(usr, SPAN_WARNING("[src] is too far away."))
				return

			for(var/datum/data/record/R in data_core.medical)
				if (R.fields["name"] == real_name)
					if(R.fields["last_scan_time"] && R.fields["last_scan_result"])
						usr << browse(R.fields["last_scan_result"], "window=scanresults;size=430x600")
					break

	if (href_list["lookitem"])
		var/obj/item/I = locate(href_list["lookitem"])
		if(istype(I))
			I.examine(usr)

	if (href_list["flavor_change"])
		switch(href_list["flavor_change"])
			if("done")
				src << browse(null, "window=flavor_changes")
				return
			if("general")
				var/msg = input(usr,"Update the general description of your character. This will be shown regardless of clothing, and may include OOC notes and preferences.","Flavor Text",html_decode(flavor_texts[href_list["flavor_change"]])) as message
				if(msg != null)
					msg = copytext(msg, 1, MAX_MESSAGE_LEN)
					msg = html_encode(msg)
				flavor_texts[href_list["flavor_change"]] = msg
				return
			else
				var/msg = input(usr,"Update the flavor text for your [href_list["flavor_change"]].","Flavor Text",html_decode(flavor_texts[href_list["flavor_change"]])) as message
				if(msg != null)
					msg = copytext(msg, 1, MAX_MESSAGE_LEN)
					msg = html_encode(msg)
				flavor_texts[href_list["flavor_change"]] = msg
				set_flavor()
				return
	..()
	return

///get_eye_protection()
///Returns a number between -1 to 2
/mob/living/carbon/human/get_eye_protection()
	var/number = 0

	if(!species.has_organ["eyes"]) return 2//No eyes, can't hurt them.

	var/datum/internal_organ/eyes/I = internal_organs_by_name["eyes"]
	if(I)
		if(I.cut_away)
			return 2
		if(I.robotic == ORGAN_ROBOT)
			return 2
	else
		return 2

	if(istype(head, /obj/item/clothing))
		var/obj/item/clothing/C = head
		number += C.eye_protection
	if(istype(wear_mask))
		number += wear_mask.eye_protection
	if(glasses)
		number += glasses.eye_protection

	return number


/mob/living/carbon/human/abiotic(var/full_body = 0)
	if(full_body && ((src.l_hand && !( src.l_hand.flags_item & ITEM_ABSTRACT)) || (src.r_hand && !( src.r_hand.flags_item & ITEM_ABSTRACT)) || (src.back || src.wear_mask || src.head || src.shoes || src.w_uniform || src.wear_suit || src.glasses || src.wear_ear || src.gloves)))
		return 1

	if( (src.l_hand && !(src.l_hand.flags_item & ITEM_ABSTRACT)) || (src.r_hand && !(src.r_hand.flags_item & ITEM_ABSTRACT)) )
		return 1

	return 0

/mob/living/carbon/human/get_species()
	if(!species)
		set_species()
	return species.name

/mob/living/carbon/human/proc/play_xylophone()
	if(!src.xylophone)
		visible_message(SPAN_DANGER("[src] begins playing his ribcage like a xylophone. It's quite spooky."),SPAN_NOTICE("You begin to play a spooky refrain on your ribcage."),SPAN_DANGER("You hear a spooky xylophone melody."))
		var/song = pick('sound/effects/xylophone1.ogg','sound/effects/xylophone2.ogg','sound/effects/xylophone3.ogg')
		playsound(loc, song, 25, 1)
		xylophone = 1
		spawn(1200)
			xylophone=0
	return

/mob/living/carbon/human/proc/vomit()

	if(species.flags & IS_SYNTHETIC)
		return //Machines don't throw up.

	if(stat == 2) //Corpses don't puke
		return

	if(!lastpuke)
		lastpuke = 1
		to_chat(src, "<spawn class='warning'>You feel nauseous...")
		spawn(150)	//15 seconds until second warning
			to_chat(src, "<spawn class='warning'>You feel like you are about to throw up!")
			spawn(100)	//and you have 10 more for mad dash to the bucket
				Stun(5)
				if(stat == 2) //One last corpse check
					return
				src.visible_message("<spawn class='warning'>[src] throws up!","<spawn class='warning'>You throw up!", null, 5)
				playsound(loc, 'sound/effects/splat.ogg', 25, 1, 7)

				var/turf/location = loc
				if (istype(location, /turf))
					location.add_vomit_floor(src, 1)

				nutrition -= 40
				adjustToxLoss(-3)
				spawn(350)	//wait 35 seconds before next volley
					lastpuke = 0

/mob/living/carbon/human/proc/morph()
	set name = "Morph"
	set category = "Superpower"

	if(stat!=CONSCIOUS)
		reset_view(0)
		remoteview_target = null
		return

	if(!(mMorph in mutations))
		src.verbs -= /mob/living/carbon/human/proc/morph
		return

	var/new_facial = input("Please select facial hair color.", "Character Generation",rgb(r_facial,g_facial,b_facial)) as color
	if(new_facial)
		r_facial = hex2num(copytext(new_facial, 2, 4))
		g_facial = hex2num(copytext(new_facial, 4, 6))
		b_facial = hex2num(copytext(new_facial, 6, 8))

	var/new_hair = input("Please select hair color.", "Character Generation",rgb(r_hair,g_hair,b_hair)) as color
	if(new_facial)
		r_hair = hex2num(copytext(new_hair, 2, 4))
		g_hair = hex2num(copytext(new_hair, 4, 6))
		b_hair = hex2num(copytext(new_hair, 6, 8))

	var/new_eyes = input("Please select eye color.", "Character Generation",rgb(r_eyes,g_eyes,b_eyes)) as color
	if(new_eyes)
		r_eyes = hex2num(copytext(new_eyes, 2, 4))
		g_eyes = hex2num(copytext(new_eyes, 4, 6))
		b_eyes = hex2num(copytext(new_eyes, 6, 8))


	// hair
	var/list/all_hairs = typesof(/datum/sprite_accessory/hair) - /datum/sprite_accessory/hair
	var/list/hairs = list()

	// loop through potential hairs
	for(var/x in all_hairs)
		var/datum/sprite_accessory/hair/H = new x // create new hair datum based on type x
		if(H.selectable)
			hairs.Add(H.name) // add hair name to hairs
		qdel(H) // delete the hair after it's all done

	var/new_style = input("Please select hair style", "Character Generation",h_style)  as null|anything in hairs

	// if new style selected (not cancel)
	if (new_style)
		h_style = new_style

	// facial hair
	var/list/all_fhairs = typesof(/datum/sprite_accessory/facial_hair) - /datum/sprite_accessory/facial_hair
	var/list/fhairs = list()

	for(var/x in all_fhairs)
		var/datum/sprite_accessory/facial_hair/H = new x
		if(H.selectable)
			fhairs.Add(H.name)
		qdel(H)

	new_style = input("Please select facial style", "Character Generation",f_style)  as null|anything in fhairs

	if(new_style)
		f_style = new_style

	var/new_gender = alert(usr, "Please select gender.", "Character Generation", "Male", "Female")
	if (new_gender)
		if(new_gender == "Male")
			gender = MALE
		else
			gender = FEMALE
	regenerate_icons()

	visible_message(SPAN_NOTICE("\The [src] morphs and changes [get_visible_gender() == MALE ? "his" : get_visible_gender() == FEMALE ? "her" : "their"] appearance!"), \
		SPAN_NOTICE("You change your appearance!"), \
		SPAN_DANGER("Oh, god!  What the hell was that?  It sounded like flesh getting squished and bone ground into a different shape!"))

/mob/living/carbon/human/proc/remotesay()
	set name = "Project mind"
	set category = "Superpower"

	if(stat!=CONSCIOUS)
		reset_view(0)
		remoteview_target = null
		return

	if(!(mRemotetalk in src.mutations))
		src.verbs -= /mob/living/carbon/human/proc/remotesay
		return
	var/list/creatures = list()
	for(var/mob/living/carbon/h in player_list)
		creatures += h
	var/mob/target = input ("Who do you want to project your mind to ?") as null|anything in creatures
	if (isnull(target))
		return

	var/say = input ("What do you wish to say")
	if(mRemotetalk in target.mutations)
		target.show_message(SPAN_NOTICE("You hear [src.real_name]'s voice: [say]"))
	else
		target.show_message(SPAN_NOTICE("You hear a voice that seems to echo around the room: [say]"))
	usr.show_message(SPAN_NOTICE("You project your mind into [target.real_name]: [say]"))
	log_say("[key_name(usr)] sent a telepathic message to [key_name(target)]: [say]")
	for(var/mob/dead/observer/G in dead_mob_list)
		G.show_message("<i>Telepathic message from <b>[src]</b> to <b>[target]</b>: [say]</i>")

/mob/living/carbon/human/proc/remoteobserve()
	set name = "Remote View"
	set category = "Superpower"

	if(stat!=CONSCIOUS)
		remoteview_target = null
		reset_view(0)
		return

	if(!(mRemote in src.mutations))
		remoteview_target = null
		reset_view(0)
		src.verbs -= /mob/living/carbon/human/proc/remoteobserve
		return

	if(client.eye != client.mob)
		remoteview_target = null
		reset_view(0)
		return

	var/list/mob/creatures = list()

	for(var/mob/living/carbon/h in player_list)
		var/turf/temp_turf = get_turf(h)
		if((temp_turf.z != 1 && temp_turf.z != 5) || h.stat!=CONSCIOUS) //Not on mining or the station. Or dead
			continue
		creatures += h

	var/mob/target = input ("Who do you want to project your mind to ?") as mob in creatures

	if (target)
		remoteview_target = target
		reset_view(target)
	else
		remoteview_target = null
		reset_view(0)

/mob/living/carbon/human/proc/get_visible_gender()
	if(wear_suit && wear_suit.flags_inv_hide & HIDEJUMPSUIT && ((head && head.flags_inv_hide & HIDEMASK) || wear_mask))
		return NEUTER
	return gender

/mob/living/carbon/human/proc/increase_germ_level(n)
	if(gloves)
		gloves.germ_level += n
	else
		germ_level += n


/mob/living/carbon/human/revive(keep_viruses)
	for (var/datum/limb/O in limbs)
		if(O.status & LIMB_ROBOT)
			O.status = LIMB_ROBOT
		else
			O.status = NOFLAGS
		O.perma_injury = 0
		O.germ_level = 0
		O.wounds.Cut()
		O.heal_damage(1000,1000,1,1)
		O.reset_limb_surgeries()

	var/datum/limb/head/h = get_limb("head")
	h.disfigured = 0
	name = get_visible_name()

	if(species && !(species.flags & NO_BLOOD))
		restore_blood()

	//try to find the brain player in the decapitated head and put them back in control of the human
	if(!client && !mind) //if another player took control of the human, we don't want to kick them out.
		for (var/obj/item/limb/head/H in item_list)
			if(H.brainmob)
				if(H.brainmob.real_name == src.real_name)
					if(H.brainmob.mind)
						H.brainmob.mind.transfer_to(src)
						qdel(H)

	for(var/datum/internal_organ/I in internal_organs)
		I.damage = 0

	if (!keep_viruses)
		for (var/datum/disease/virus in viruses)
			if (istype(virus, /datum/disease/black_goo))
				continue
			virus.cure(0)

	undefibbable = FALSE
	..()

/mob/living/carbon/human/proc/is_lung_ruptured()
	var/datum/internal_organ/lungs/L = internal_organs_by_name["lungs"]
	return L && L.is_bruised()

/mob/living/carbon/human/proc/rupture_lung()
	var/datum/internal_organ/lungs/L = internal_organs_by_name["lungs"]

	if(L && !L.is_bruised())
		src.custom_pain("You feel a stabbing pain in your chest!", 1)
		L.damage = L.min_bruised_damage



/mob/living/carbon/human/get_visible_implants(var/class = 0)

	var/list/visible_implants = list()
	for(var/datum/limb/organ in limbs)
		for(var/obj/item/O in organ.implants)
			if(!istype(O,/obj/item/implant) && (O.w_class > class) && !istype(O,/obj/item/shard/shrapnel))
				visible_implants += O

	return(visible_implants)

/mob/living/carbon/human/proc/handle_embedded_objects()

	for(var/datum/limb/organ in limbs)
		if(organ.status & LIMB_SPLINTED) //Splints prevent movement.
			continue
		for(var/obj/item/O in organ.implants)
			if(!istype(O,/obj/item/implant) && prob(4)) //Moving with things stuck in you could be bad.
				// All kinds of embedded objects cause bleeding.
				var/msg = null
				switch(rand(1,3))
					if(1)
						msg =SPAN_WARNING("A spike of pain jolts your [organ.display_name] as you bump [O] inside.")
					if(2)
						msg =SPAN_WARNING("Your movement jostles [O] in your [organ.display_name] painfully.")
					if(3)
						msg =SPAN_WARNING("[O] in your [organ.display_name] twists painfully as you move.")
				src << msg

				organ.take_damage(rand(1,2), 0, 0)
				if(!(organ.status & LIMB_ROBOT) && !(species.flags & NO_BLOOD)) //There is no blood in protheses.
					organ.status |= LIMB_BLEEDING
					if(prob(10)) src.adjustToxLoss(1)

/mob/living/carbon/human/verb/check_pulse()
	set category = "Object"
	set name = "Check pulse"
	set desc = "Approximately count somebody's pulse. Requires you to stand still at least 6 seconds."
	set src in view(1)
	var/self = 0

	if(usr.stat > 0 || usr.is_mob_restrained() || !isliving(usr)) return

	if(usr == src)
		self = 1
	if(!self)
		usr.visible_message(SPAN_NOTICE("[usr] kneels down, puts \his hand on [src]'s wrist and begins counting their pulse."),\
		"You begin counting [src]'s pulse", null, 3)
	else
		usr.visible_message(SPAN_NOTICE("[usr] begins counting their pulse."),\
		"You begin counting your pulse.", null, 3)

	if(src.pulse)
		to_chat(usr, SPAN_NOTICE(" [self ? "You have a" : "[src] has a"] pulse! Counting..."))
	else
		to_chat(usr, SPAN_DANGER("[src] has no pulse!"))	//it is REALLY UNLIKELY that a dead person would check his own pulse
		return

	to_chat(usr, "Don't move until counting is finished.")
	var/time = world.time
	sleep(60)
	if(usr.l_move_time >= time)	//checks if our mob has moved during the sleep()
		to_chat(usr, "You moved while counting. Try again.")
	else
		var/pronoun = "[self ? "Your" : "[src]'s"]"
		to_chat(usr, SPAN_NOTICE(" [pronoun] pulse is [src.get_pulse(GETPULSE_HAND)]."))

/mob/living/carbon/human/verb/view_manifest()
	set name = "View Crew Manifest"
	set category = "IC"

	var/dat
	dat += "<h4>Crew Manifest</h4>"
	dat += data_core.get_manifest()

	src << browse(dat, "window=manifest;size=370x420;can_close=1")

/mob/living/carbon/human/proc/set_species(var/new_species, var/default_colour)
	if(!new_species)
		new_species = "Human"

	if(species)
		if(species.name && species.name == new_species) //we're already that species.
			return

		// Clear out their species abilities.
		species.remove_inherent_verbs(src)

	var/datum/species/oldspecies = species

	species = all_species[new_species]

	if(oldspecies)
		//additional things to change when we're no longer that species
		oldspecies.post_species_loss(src)

	species.create_organs(src)

	if(species.base_color && default_colour)
		//Apply colour.
		r_skin = hex2num(copytext(species.base_color,2,4))
		g_skin = hex2num(copytext(species.base_color,4,6))
		b_skin = hex2num(copytext(species.base_color,6,8))
	else
		r_skin = 0
		g_skin = 0
		b_skin = 0

	if(species.hair_color)
		r_hair = hex2num(copytext(species.hair_color, 2, 4))
		g_hair = hex2num(copytext(species.hair_color, 4, 6))
		b_hair = hex2num(copytext(species.hair_color, 6, 8))

	species.handle_post_spawn(src)

	spawn(0)
		regenerate_icons()
		restore_blood()
		update_body(1,0)
		update_hair()


	if(species)
		return 1
	else
		return 0

/mob/living/carbon/human/proc/bloody_doodle()
	set category = "IC"
	set name = "Write in blood"
	set desc = "Use blood on your hands to write a short message on the floor or a wall, murder mystery style."

	if (src.stat)
		return

	if (usr != src)
		return 0 //something is terribly wrong

	if (!bloody_hands)
		verbs -= /mob/living/carbon/human/proc/bloody_doodle

	if (src.gloves)
		to_chat(src, SPAN_WARNING("Your [src.gloves] are getting in the way."))
		return

	var/turf/T = src.loc
	if (!istype(T)) //to prevent doodling out of mechs and lockers
		to_chat(src, SPAN_WARNING("You cannot reach the floor."))
		return

	var/direction = input(src,"Which way?","Tile selection") as anything in list("Here","North","South","East","West")
	if (direction != "Here")
		T = get_step(T,text2dir(direction))
	if (!istype(T))
		to_chat(src, SPAN_WARNING("You cannot doodle there."))
		return

	var/num_doodles = 0
	for (var/obj/effect/decal/cleanable/blood/writing/W in T)
		num_doodles++
	if (num_doodles > 4)
		to_chat(src, SPAN_WARNING("There is no space to write on!"))
		return

	var/max_length = bloody_hands * 30 //tweeter style

	var/message = stripped_input(src,"Write a message. It cannot be longer than [max_length] characters.","Blood writing", "")

	if (message)
		var/used_blood_amount = round(length(message) / 30, 1)
		bloody_hands = max(0, bloody_hands - used_blood_amount) //use up some blood

		if (length(message) > max_length)
			message += "-"
			to_chat(src, SPAN_WARNING("You ran out of blood to write with!"))

		var/obj/effect/decal/cleanable/blood/writing/W = new(T)
		W.basecolor = (blood_color) ? blood_color : "#A10808"
		W.update_icon()
		W.message = message
		W.add_fingerprint(src)

/mob/living/carbon/human/print_flavor_text()
	var/list/equipment = list(src.head,src.wear_mask,src.glasses,src.w_uniform,src.wear_suit,src.gloves,src.shoes)
	var/head_exposed = 1
	var/face_exposed = 1
	var/eyes_exposed = 1
	var/torso_exposed = 1
	var/arms_exposed = 1
	var/legs_exposed = 1
	var/hands_exposed = 1
	var/feet_exposed = 1

	for(var/obj/item/clothing/C in equipment)
		if(C.flags_armor_protection & HEAD)
			head_exposed = 0
		if(C.flags_armor_protection & FACE)
			face_exposed = 0
		if(C.flags_armor_protection & EYES)
			eyes_exposed = 0
		if(C.flags_armor_protection & UPPER_TORSO)
			torso_exposed = 0
		if(C.flags_armor_protection & ARMS)
			arms_exposed = 0
		if(C.flags_armor_protection & HANDS)
			hands_exposed = 0
		if(C.flags_armor_protection & LEGS)
			legs_exposed = 0
		if(C.flags_armor_protection & FEET)
			feet_exposed = 0

	flavor_text = flavor_texts["general"]
	flavor_text += "\n\n"
	for (var/T in flavor_texts)
		if(flavor_texts[T] && flavor_texts[T] != "")
			if((T == "head" && head_exposed) || (T == "face" && face_exposed) || (T == "eyes" && eyes_exposed) || (T == "torso" && torso_exposed) || (T == "arms" && arms_exposed) || (T == "hands" && hands_exposed) || (T == "legs" && legs_exposed) || (T == "feet" && feet_exposed))
				flavor_text += flavor_texts[T]
				flavor_text += "\n\n"
	return ..()



/mob/living/carbon/human/proc/vomit_on_floor()
	var/turf/T = get_turf(src)
	visible_message(SPAN_DANGER("[src] vomits on the floor!"), null, null, 5)
	nutrition -= 20
	adjustToxLoss(-3)
	playsound(T, 'sound/effects/splat.ogg', 25, 1, 7)
	T.add_vomit_floor(src)

/mob/living/carbon/human/slip(slip_source_name, stun_level, weaken_level, run_only, override_noslip, slide_steps)
	if(shoes && !override_noslip) // && (shoes.flags_inventory & NOSLIPPING)) // no more slipping if you have shoes on. -spookydonut
		return FALSE
	. = ..()



//very similar to xeno's queen_locator() but this is for locating squad leader.
/mob/living/carbon/human/proc/locate_squad_leader()
	if(!assigned_squad) return
	var/mob/living/carbon/human/H = assigned_squad.squad_leader
	if(!H)
		hud_used.locate_leader.icon_state = "trackoff"
		return

	if(H.z != src.z || get_dist(src,H) < 1 || src == H)
		hud_used.locate_leader.icon_state = "trackondirect"
	else
		hud_used.locate_leader.dir = get_dir(src,H)
		hud_used.locate_leader.icon_state = "trackon"


/mob/living/carbon/proc/locate_nearest_nuke()
	if(!bomb_set) return
	var/obj/machinery/nuclearbomb/N
	for(var/obj/machinery/nuclearbomb/bomb in world)
		if(!istype(N) || N.z != src.z )
			N = bomb
		if(bomb.z == src.z && get_dist(src,bomb) < get_dist(src,N))
			N = bomb
	if(N.z != src.z || !N)
		hud_used.locate_nuke.icon_state = "trackoff"
		return

	if(get_dist(src,N) < 1)
		hud_used.locate_nuke.icon_state = "nuke_trackondirect"
	else
		hud_used.locate_nuke.dir = get_dir(src,N)
		hud_used.locate_nuke.icon_state = "nuke_trackon"




/mob/proc/update_sight()
	return

/mob/living/carbon/human/update_sight()
	if(stat == DEAD)
		sight |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = 8
		see_invisible = SEE_INVISIBLE_LEVEL_TWO
	else
		sight &= ~(SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = species.darksight
		see_invisible = see_in_dark > 2 ? SEE_INVISIBLE_LEVEL_ONE : SEE_INVISIBLE_LIVING
		/* //TODO: remove once we confirm shadows don't need this
		if(dna)
			switch(dna.mutantrace)
				if("slime")
					see_in_dark = 3
					see_invisible = SEE_INVISIBLE_LEVEL_ONE
				if("shadow")
					see_in_dark = 8
					see_invisible = SEE_INVISIBLE_LEVEL_ONE

		if(XRAY in mutations)
			sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
			see_in_dark = 8
			see_invisible = SEE_INVISIBLE_LEVEL_TWO
		*/
		if(glasses)
			process_glasses(glasses)
		else
			see_invisible = SEE_INVISIBLE_LIVING




/mob/proc/update_tint()

/mob/living/carbon/human/update_tint()
	var/is_tinted = FALSE

	if(istype(head, /obj/item/clothing/head/welding))
		var/obj/item/clothing/head/welding/O = head
		if(!O.up && tinted_weldhelh)
			is_tinted = TRUE

	if(glasses && glasses.has_tint && glasses.active && tinted_weldhelh)
		is_tinted = TRUE

	if(istype(wear_mask, /obj/item/clothing/mask/gas))
		var/obj/item/clothing/mask/gas/G = wear_mask
		if(G.vision_impair && tinted_weldhelh)
			is_tinted = TRUE

	if(is_tinted)
		overlay_fullscreen("tint", /obj/screen/fullscreen/impaired, 2)
		return 1
	else
		clear_fullscreen("tint", 0)
		return 0


/mob/proc/update_glass_vision(obj/item/clothing/glasses/G)
	return

/mob/living/carbon/human/update_glass_vision(obj/item/clothing/glasses/G)
	if(G.fullscreen_vision)
		if(G == glasses && G.active) //equipped and activated
			overlay_fullscreen("glasses_vision", G.fullscreen_vision)
			return 1
		else //unequipped or deactivated
			clear_fullscreen("glasses_vision", 0)

/mob/living/carbon/human/verb/checkSkills()
	set name = "Check Skills"
	set category = "IC"
	set src = usr

	var/dat = "<b><font size = 5>Skills:</font></b><br/><br/>"
	if(!usr || !usr.mind || !usr.mind.cm_skills)
		dat += "NULL<br/>"
	else
		dat += "CQC: [usr.mind.cm_skills.cqc]<br/>"
		dat += "Melee: [usr.mind.cm_skills.melee_weapons]<br/>"
		dat += "Firearms: [usr.mind.cm_skills.firearms]<br/>"
		dat += "Pistols: [usr.mind.cm_skills.pistols]<br/>"
		dat += "Shotguns: [usr.mind.cm_skills.shotguns]<br/>"
		dat += "Rifles: [usr.mind.cm_skills.rifles]<br/>"
		dat += "SMGs: [usr.mind.cm_skills.smgs]<br/>"
		dat += "Heavy Weapons: [usr.mind.cm_skills.heavy_weapons]<br/>"
		dat += "Smartgun: [usr.mind.cm_skills.smartgun]<br/>"
		dat += "Specialist Weapons: [usr.mind.cm_skills.spec_weapons]<br/>"
		dat += "Endurance: [usr.mind.cm_skills.endurance]<br/>"
		dat += "Engineer: [usr.mind.cm_skills.engineer]<br/>"
		dat += "Construction: [usr.mind.cm_skills.construction]<br/>"
		dat += "Leadership: [usr.mind.cm_skills.leadership]<br/>"
		dat += "Medical: [usr.mind.cm_skills.medical]<br/>"
		dat += "Surgery: [usr.mind.cm_skills.surgery]<br/>"
		dat += "Pilot: [usr.mind.cm_skills.pilot]<br/>"
		dat += "Police: [usr.mind.cm_skills.police]<br/>"
		dat += "Powerloader: [usr.mind.cm_skills.powerloader]<br/>"
		dat += "Large Vehicle: [usr.mind.cm_skills.large_vehicle]<br/>"

	src << browse(dat, "window=checkskills")
	return

/mob/living/carbon/human/verb/remove_your_splints()
	set name = "Remove Your Splints"
	set category = "Object"

	remove_splints()

// target = person whose splints are being removed
// source = person removing the splints
/mob/living/carbon/human/proc/remove_splints(mob/living/carbon/human/source)
	var/mob/living/carbon/human/HT = src
	var/mob/living/carbon/human/HS = source

	if(!istype(HS))
		HS = src
	if(!istype(HS) || !istype(HT))
		return

	var/cur_hand = "l_hand"
	if(!HS.hand)
		cur_hand = "r_hand"

	if(!HS.action_busy)
		var/list/datum/limb/to_splint = list()
		var/same_arm_side = FALSE // If you are trying to splint yourself, need opposite hand to splint an arm/hand
		if (HS.get_limb(cur_hand).status & LIMB_DESTROYED)
			to_chat(HS, SPAN_WARNING("You cannot remove splints without a hand."))
			return
		for(var/bodypart in list("l_leg","r_leg","l_arm","r_arm","r_hand","l_hand","r_foot","l_foot","chest","head","groin"))
			var/datum/limb/l = HT.get_limb(bodypart)
			if (l && l.status & LIMB_SPLINTED)
				if (HS == HT)
					if ((bodypart in list("l_arm", "l_hand")) && (cur_hand == "l_hand"))
						same_arm_side = TRUE
						continue
					if ((bodypart in list("r_arm", "r_hand")) && (cur_hand == "r_hand"))
						same_arm_side = TRUE
						continue
				to_splint.Add(l)

		var/msg = "" // Have to use this because there are issues with the to_chat macros and text macros and quotation marks
		if(to_splint.len)
			if(do_after(HS, HUMAN_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, HT, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
				var/can_reach_splints = TRUE
				var/amount_removed = 0
				if(wear_suit && istype(wear_suit,/obj/item/clothing/suit/space))
					var/obj/item/clothing/suit/space/suit = HT.wear_suit
					if(suit.supporting_limbs && suit.supporting_limbs.len)
						msg = "[HS == HT ? "your":"\proper [HT]'s"]"
						to_chat(HS, SPAN_WARNING("You cannot remove the splints, [msg] [suit] is supporting some of the breaks."))
						can_reach_splints = FALSE
				if(can_reach_splints)
					var/obj/item/stack/W = new /obj/item/stack/medical/splint(HS.loc)
					W.amount = 0 //we checked that we have at least one bodypart splinted, so we can create it no prob. Also we need amount to be 0
					W.add_fingerprint(HS)
					for (var/datum/limb/l in to_splint)
						amount_removed += 1
						l.status &= ~LIMB_SPLINTED
						if(!W.add(1))
							W = new /obj/item/stack/medical/splint(HS.loc)//old stack is dropped, time for new one
							W.amount = 0
							W.add_fingerprint(HS)
							W.add(1)
					msg = "[HS == HT ? "their own":"\proper [HT]'s"]"
					HT.visible_message(SPAN_NOTICE("[HS] removes [msg] [amount_removed>1 ? "splints":"splint"]."), \
						SPAN_NOTICE("Your [amount_removed>1 ? "splints are":"splint is"] removed."))
					HT.update_med_icon()
			else
				msg = "[HS == HT ? "your":"\proper [HT]'s"]"
				to_chat(HS, SPAN_NOTICE("You stop trying to remove [msg] splints."))
		else
			if(same_arm_side)
				to_chat(HS, SPAN_WARNING("You need to use the opposite hand to remove the splints on your arm and hand!"))
			else
				to_chat(HS, SPAN_WARNING("There are no splints to remove."))

/mob/living/carbon/human/yautja/New()
	..()
	set_species("Yautja")

/mob/living/carbon/human/monkey/New()
	..()
	set_species("Monkey")

/mob/living/carbon/human/farwa/New()
	..()
	set_species("Farwa")

/mob/living/carbon/human/neaera/New()
	..()
	set_species("Neaera")

/mob/living/carbon/human/stok/New()
	..()
	set_species("Stok")

/mob/living/carbon/human/yiren/New()
	..()
	set_species("Yiren")