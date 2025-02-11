var/list/loadout_categories = list()
var/list/gear_datums = list()

/datum/preferences
	var/list/gear_list //Custom/fluff item loadouts.
	var/gear_slot = 1  //The current gear save slot

/datum/preferences/proc/Gear()
	return gear_list[gear_slot]

/datum/loadout_category
	var/category = ""
	var/list/gear = list()

/datum/loadout_category/New(var/cat)
	category = cat
	..()

/hook/startup/proc/populate_gear_list()

	//create a list of gear datums to sort
	for(var/geartype in typesof(/datum/gear)-/datum/gear)
		var/datum/gear/G = geartype
		if(initial(G.category) == geartype)
			continue
		if(GLOB.using_map.loadout_blacklist && (geartype in GLOB.using_map.loadout_blacklist))
			continue
		if(!length_char(initial(G.display_name)))
			continue

		var/use_name = initial(G.display_name)
		var/use_category = initial(G.sort_category)

		if(!loadout_categories[use_category])
			loadout_categories[use_category] = new /datum/loadout_category(use_category)
		var/datum/loadout_category/LC = loadout_categories[use_category]
		gear_datums[use_name] = new geartype
		LC.gear[use_name] = gear_datums[use_name]

	loadout_categories = sortAssoc(loadout_categories)
	for(var/loadout_category in loadout_categories)
		var/datum/loadout_category/LC = loadout_categories[loadout_category]
		LC.gear = sortAssoc(LC.gear)
	return 1

/datum/category_item/player_setup_item/loadout
	name = "Loadout"
	sort_order = 1
	var/current_tab = "General"
	var/hide_unavailable_gear = 0

/datum/category_item/player_setup_item/loadout/load_character(datum/pref_record_reader/R)
	pref.gear_list = R.read("gear_list")
	pref.gear_slot = R.read("gear_slot")

/datum/category_item/player_setup_item/loadout/save_character(datum/pref_record_writer/W)
	W.write("gear_list", pref.gear_list)
	W.write("gear_slot", pref.gear_slot)

/datum/category_item/player_setup_item/loadout/proc/valid_gear_choices(var/max_cost)
	. = list()
	var/mob/preference_mob = preference_mob()
	for(var/gear_name in gear_datums)
		var/datum/gear/G = gear_datums[gear_name]
		var/okay = 1
		if(G.whitelisted && preference_mob)
			okay = 0
			for(var/species in G.whitelisted)
				if(is_species_whitelisted(preference_mob, species))
					okay = 1
					break
		if(!okay)
			continue
		if(!gear_allowed_to_equip(G, preference_mob))
			continue
		if(max_cost && G.cost > max_cost)
			continue
		. += gear_name

/datum/category_item/player_setup_item/loadout/proc/skill_check(var/list/jobs, var/list/skills_required)
	for(var/datum/job/J in jobs)
		. = TRUE
		for(var/R in skills_required)
			if(pref.get_total_skill_value(J, R) < skills_required[R])
				. = FALSE
				break
		if(.)
			return

/datum/category_item/player_setup_item/loadout/sanitize_character()
	pref.gear_slot = sanitize_integer(pref.gear_slot, 1, config.loadout_slots, initial(pref.gear_slot))
	if(!islist(pref.gear_list)) pref.gear_list = list()

	if(pref.gear_list.len < config.loadout_slots)
		pref.gear_list.len = config.loadout_slots

	for(var/index = 1 to config.loadout_slots)
		var/list/gears = pref.gear_list[index]

		if(istype(gears))
			for(var/gear_name in gears)
				if(!(gear_name in gear_datums))
					gears -= gear_name

			var/total_cost = 0
			for(var/gear_name in gears)
				if(!gear_datums[gear_name])
					gears -= gear_name
				else if(!(gear_name in valid_gear_choices()))
					gears -= gear_name
				else
					var/datum/gear/G = gear_datums[gear_name]
					if(total_cost + G.cost > config.max_gear_cost)
						gears -= gear_name
					else
						total_cost += G.cost
		else
			pref.gear_list[index] = list()

/datum/category_item/player_setup_item/loadout/content()
	. = list()
	var/total_cost = 0
	var/list/gears = pref.gear_list[pref.gear_slot]
	for(var/i = 1; i <= gears.len; i++)
		var/datum/gear/G = gear_datums[gears[i]]
		if(G)
			total_cost += G.cost

	var/fcolor =  "#3366cc"
	if(total_cost < config.max_gear_cost)
		fcolor = "#e67300"
	. += "<table align = 'center' width = 100%>"
	. += "<tr><td colspan=3><center>"
	. += "<a href='?src=\ref[src];prev_slot=1'>\<=</a><b><font color = '[fcolor]'>\[[pref.gear_slot]\]</font> </b><a href='?src=\ref[src];next_slot=1'>=\></a>"

	if(config.max_gear_cost < INFINITY)
		. += "<b><font color = '[fcolor]'>[total_cost]/[config.max_gear_cost]</font> loadout points spent.</b>"

	. += "<a href='?src=\ref[src];clear_loadout=1'>Clear Loadout</a>"
	. += "<a href='?src=\ref[src];toggle_hiding=1'>[hide_unavailable_gear ? "Show all" : "Hide unavailable"]</a></center></td></tr>"

	. += "<tr><td colspan=3><center><b>"
	var/firstcat = 1
	for(var/category in loadout_categories)

		if(firstcat)
			firstcat = 0
		else
			. += " |"

		var/datum/loadout_category/LC = loadout_categories[category]
		var/category_cost = 0
		for(var/gear in LC.gear)
			if(gear in pref.gear_list[pref.gear_slot])
				var/datum/gear/G = LC.gear[gear]
				category_cost += G.cost

		if(category == current_tab)
			. += " <span class='linkOn'>[category] - [category_cost]</span> "
		else
			if(category_cost)
				. += " <a href='?src=\ref[src];select_category=[category]'><font color = '#e67300'>[category] - [category_cost]</font></a> "
			else
				. += " <a href='?src=\ref[src];select_category=[category]'>[category] - 0</a> "

	. += "</b></center></td></tr>"

	var/datum/loadout_category/LC = loadout_categories[current_tab]
/*[BAY]
	. += "<tr><td colspan=3><hr></td></tr>"
	. += "<tr><td colspan=3><b><center>[LC.category]</center></b></td></tr>"
	. += "<tr><td colspan=3><hr></td></tr>"
[/BAY]*/
//[INF]
	. += "<tr><td colspan=5><hr></td></tr>"
	. += "<tr><td colspan=5><b><center>[LC.category]</center></b></td></tr>"
	. += "<tr><td colspan=5><hr></td></tr>"
	. += "<tr><th>Name<th>Slots' Cost<th>Description<th>Premium Cost<th>Premium Level"
//[/INF]
	var/jobs = list()
	for(var/job_title in (pref.job_medium|pref.job_low|pref.job_high))
		var/datum/job/J = SSjobs.get_by_title(job_title)
		if(J)
			dd_insertObjectList(jobs, J)
	var/list/valid_gear_list = valid_gear_choices() //INF
	for(var/gear_name in LC.gear)
		if(!list_find(valid_gear_list, gear_name))//inf, was: if(!(gear_name in valid_gear_choices()))
			continue
		var/list/entry = list()
		var/datum/gear/G = LC.gear[gear_name]
		var/ticked = (G.display_name in pref.gear_list[pref.gear_slot])
		//[INF]

		var/list/gear_link_class = list()
		if(ticked)
			gear_link_class.Add("linkOn")
		if(G.price > 0 || G.required_donate_level > 0)
			gear_link_class.Add("donate")
		gear_link_class = jointext(gear_link_class, " ")

		var/text_style = "vertical-align:top;text-align:center;"
		//[/INF]
		entry += "<tr style='vertical-align:top;'><td><a style='white-space:normal;' class='[gear_link_class]' href='?src=\ref[src];toggle_gear=\ref[G]'>[G.display_name]</a></td>" //inf, was: entry += "<tr style='vertical-align:top;'><td width=25%><a style='white-space:normal;' [ticked ? "class='linkOn' " : ""]href='?src=\ref[src];toggle_gear=\ref[G]'>[G.display_name]</a></td>"
		entry += "<td style='[text_style]'>[G.cost]</td>"//inf, was: entry += "<td width = 10% style='vertical-align:top'>[G.cost]</td>"
		entry += "<td><font size=2>[G.get_description(get_gear_metadata(G,1))]</font>"
		var/allowed = 1
		if(allowed && G.allowed_roles)
			var/good_job = 0
			var/bad_job = 0
			entry += "<br><i>"
			var/list/jobchecks = list()
			for(var/datum/job/J in jobs)
				if(J.type in G.allowed_roles)
					jobchecks += "<font color=55cc55>[J.title]</font>"
					good_job = 1
				else
					jobchecks += "<font color=cc5555>[J.title]</font>"
					bad_job = 1
			allowed = good_job || !bad_job
			entry += "[english_list(jobchecks)]</i>"

		if(allowed && G.allowed_branches)
			var/list/branches = list()
			for(var/datum/job/J in jobs)
				if(pref.branches[J.title])
					branches |= pref.branches[J.title]
			if(length(branches))
				var/list/branch_checks = list()
				var/good_branch = 0
				entry += "<br><i>"
				for(var/branch in branches)
					var/datum/mil_branch/player_branch = mil_branches.get_branch(branch)
					if(player_branch.type in G.allowed_branches)
						branch_checks += "<font color=55cc55>[player_branch.name]</font>"
						good_branch = 1
					else
						branch_checks += "<font color=cc5555>[player_branch.name]</font>"
				allowed = good_branch

				entry += "[english_list(branch_checks)]</i>"

		if(allowed && G.allowed_skills)
			var/list/skills_required = list()//make it into instances? instead of path
			for(var/skill in G.allowed_skills)
				var/decl/hierarchy/skill/instance = decls_repository.get_decl(skill)
				skills_required[instance] = G.allowed_skills[skill]

			allowed = skill_check(jobs, skills_required)//Checks if a single job has all the skills required

			entry += "<br><i>"
			var/list/skill_checks = list()
			for(var/R in skills_required)
				var/decl/hierarchy/skill/S = R
				var/skill_entry
				skill_entry += "[S.levels[skills_required[R]]]"
				if(allowed)
					skill_entry = "<font color=55cc55>[skill_entry] [R]</font>"
				else
					skill_entry = "<font color=cc5555>[skill_entry] [R]</font>"
				skill_checks += skill_entry

			entry += "[english_list(skill_checks)]</i>"
		//[INF]
		entry += "<td style='[text_style]'>[G.price]"
		entry += "<td style='[text_style]'>[G.required_donate_level]"
		//[/INF]
		entry += "</tr>"
		if(ticked)
			entry += "<tr><td colspan=3>"
			for(var/datum/gear_tweak/tweak in G.gear_tweaks)
				var/contents = tweak.get_contents(get_tweak_metadata(G, tweak))
				if(contents)
					entry += " <a href='?src=\ref[src];gear=\ref[G];tweak=\ref[tweak]'>[contents]</a>"
			entry += "</td></tr>"
		if(!hide_unavailable_gear || allowed || ticked)
			. += entry
	. += "</table>"
	. = jointext(.,null)

/datum/category_item/player_setup_item/loadout/proc/get_gear_metadata(var/datum/gear/G, var/readonly)
	var/list/gear = pref.gear_list[pref.gear_slot]
	. = gear[G.display_name]
	if(!.)
		. = list()
		if(!readonly)
			gear[G.display_name] = .

/datum/category_item/player_setup_item/loadout/proc/get_tweak_metadata(var/datum/gear/G, var/datum/gear_tweak/tweak)
	var/list/metadata = get_gear_metadata(G)
	. = metadata["[tweak]"]
	if(!.)
		. = tweak.get_default()
		metadata["[tweak]"] = .

/datum/category_item/player_setup_item/loadout/proc/set_tweak_metadata(var/datum/gear/G, var/datum/gear_tweak/tweak, var/new_metadata)
	var/list/metadata = get_gear_metadata(G)
	metadata["[tweak]"] = new_metadata

/datum/category_item/player_setup_item/loadout/OnTopic(href, href_list, user)
	if(href_list["toggle_gear"])
		var/datum/gear/TG = locate(href_list["toggle_gear"])
		if(!istype(TG) || gear_datums[TG.display_name] != TG)
			return TOPIC_REFRESH
		if((TG.display_name in pref.gear_list[pref.gear_slot]) || !gear_allowed_to_equip(TG, user)) //inf, was: if(TG.display_name in pref.gear_list[pref.gear_slot])
			pref.gear_list[pref.gear_slot] -= TG.display_name
		else
			var/total_cost = 0
			for(var/gear_name in pref.gear_list[pref.gear_slot])
				var/datum/gear/G = gear_datums[gear_name]
				if(istype(G)) total_cost += G.cost
			if(((total_cost + TG.cost) <= config.max_gear_cost) && gear_allowed_to_equip(TG, user)) //inf, was: if((total_cost+TG.cost) <= config.max_gear_cost)
				pref.gear_list[pref.gear_slot] += TG.display_name
		return TOPIC_REFRESH_UPDATE_PREVIEW
	if(href_list["gear"] && href_list["tweak"])
		var/datum/gear/gear = locate(href_list["gear"])
		var/datum/gear_tweak/tweak = locate(href_list["tweak"])
		if(!tweak || !istype(gear) || !(tweak in gear.gear_tweaks) || gear_datums[gear.display_name] != gear)
			return TOPIC_NOACTION
		var/metadata = tweak.get_metadata(user, get_tweak_metadata(gear, tweak))
		if(!metadata || !CanUseTopic(user))
			return TOPIC_NOACTION
		set_tweak_metadata(gear, tweak, metadata)
		return TOPIC_REFRESH_UPDATE_PREVIEW
	if(href_list["next_slot"])
		pref.gear_slot = pref.gear_slot+1
		if(pref.gear_slot > config.loadout_slots)
			pref.gear_slot = 1
		return TOPIC_REFRESH_UPDATE_PREVIEW
	if(href_list["prev_slot"])
		pref.gear_slot = pref.gear_slot-1
		if(pref.gear_slot < 1)
			pref.gear_slot = config.loadout_slots
		return TOPIC_REFRESH_UPDATE_PREVIEW
	if(href_list["select_category"])
		current_tab = href_list["select_category"]
		return TOPIC_REFRESH
	if(href_list["clear_loadout"])
		var/list/gear = pref.gear_list[pref.gear_slot]
		gear.Cut()
		return TOPIC_REFRESH_UPDATE_PREVIEW
	if(href_list["toggle_hiding"])
		hide_unavailable_gear = !hide_unavailable_gear
		return TOPIC_REFRESH
	return ..()

/datum/gear
	var/display_name       //Name/index. Must be unique.
	var/description        //Description of this gear. If left blank will default to the description of the pathed item.
	var/path               //Path to item.
	var/cost = 1           //Number of points used. Items in general cost 1 point, storage/armor/gloves/special use costs 2 points.
	var/slot               //Slot to equip to.
	var/list/allowed_roles //Roles that can spawn with this item.
	var/list/allowed_branches //Service branches that can spawn with it.
	var/list/allowed_skills //Skills required to spawn with this item.
	var/whitelisted        //Term to check the whitelist for..
	var/sort_category = "General"
	var/flags              //Special tweaks in New
	var/custom_setup_proc  //Special tweak in New
	var/category
	var/list/gear_tweaks = list() //List of datums which will alter the item after it has been spawned.

/datum/gear/New()
	if(HAS_FLAGS(flags, GEAR_HAS_TYPE_SELECTION|GEAR_HAS_SUBTYPE_SELECTION))
		CRASH("May not have both type and subtype selection tweaks")
	if(!description)
		var/obj/O = path
		description = initial(O.desc)
	if(flags & GEAR_HAS_COLOR_SELECTION)
		gear_tweaks += gear_tweak_free_color_choice()
	if(flags & GEAR_HAS_TYPE_SELECTION)
		gear_tweaks += new/datum/gear_tweak/path/type(path)
	if(flags & GEAR_HAS_SUBTYPE_SELECTION)
		gear_tweaks += new/datum/gear_tweak/path/subtype(path)
	if(custom_setup_proc)
		gear_tweaks += new/datum/gear_tweak/custom_setup(custom_setup_proc)

/datum/gear/proc/get_description(var/metadata)
	. = description
	for(var/datum/gear_tweak/gt in gear_tweaks)
		. = gt.tweak_description(., metadata["[gt]"])

/datum/gear_data
	var/path
	var/location

/datum/gear_data/New(var/path, var/location)
	src.path = path
	src.location = location

/datum/gear/proc/spawn_item(user, location, metadata)
	var/datum/gear_data/gd = new(path, location)
	for(var/datum/gear_tweak/gt in gear_tweaks)
		gt.tweak_gear_data(metadata && metadata["[gt]"], gd)
	var/item = new gd.path(gd.location)
	for(var/datum/gear_tweak/gt in gear_tweaks)
		gt.tweak_item(user, item, metadata && metadata["[gt]"])
	return item

/datum/gear/proc/spawn_on_mob(var/mob/living/carbon/human/H, var/metadata)
	var/obj/item/item = spawn_item(H, H, metadata)
	if(H.equip_to_slot_if_possible(item, slot, del_on_fail = 1, force = 1))
		. = item

/datum/gear/proc/spawn_in_storage_or_drop(var/mob/living/carbon/human/H, var/metadata)
	var/obj/item/item = spawn_item(H, H, metadata)
	item.add_fingerprint(H)

	// Roundstart augments require special handling in order to properly install
	// Putting this in "spawn_on_mob" requires overriding a bunch of logic, so we hook into here instead
	if (istype(item, /obj/item/organ/internal/augment))
		var/obj/item/organ/internal/augment/A = item
		var/obj/item/organ/external/affected = H.get_organ(A.parent_organ)
		if (!affected)
			to_chat(H, SPAN_WARNING("Failed to install \the [A]!"))
			QDEL_NULL(A)
		else
			var/beep_boop = BP_IS_ROBOTIC(affected)
			var/obj/item/organ/internal/I = H.internal_organs_by_name[A.organ_tag]
			if (!(A.augment_flags & AUGMENTATION_MECHANIC) && beep_boop)
				to_chat(H, SPAN_WARNING("\The [A] cannot be installed in a robotic part!"))
				QDEL_NULL(A)
			else if (!(A.augment_flags & AUGMENTATION_ORGANIC) && !beep_boop)
				to_chat(H, SPAN_WARNING("\The [A] cannot be installed in an organic part!"))
				QDEL_NULL(A)
			else if(I && (I.parent_organ == A.parent_organ))
				to_chat(H, SPAN_WARNING("\The [A] could not be installed because you can only have one [A.organ_tag] at a time."))
				QDEL_NULL(A)
			else
				to_chat(H, SPAN_NOTICE("Installing \the [A] in your [affected.name]!"))
				A.forceMove(H)
				A.replaced(H, affected)
				A.onRoundstart()
				. = A
	else
		var/atom/placed_in = H.equip_to_storage(item)
		if(placed_in)
			to_chat(H, SPAN_NOTICE("Placing \the [item] in your [placed_in.name]!"))
		else if(H.equip_to_appropriate_slot(item))
			to_chat(H, SPAN_NOTICE("Placing \the [item] in your inventory!"))
		else if(H.put_in_hands(item))
			to_chat(H, SPAN_NOTICE("Placing \the [item] in your hands!"))
		else
			to_chat(H, SPAN_DANGER("Dropping \the [item] on the ground!"))
