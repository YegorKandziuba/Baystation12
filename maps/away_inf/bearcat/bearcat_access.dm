/var/const/access_bearcat_inf = "ACCESS_BEARCAT" //998
/datum/access/bearcat
	id = access_bearcat_inf
	desc = "FTU Crewman"
	region = ACCESS_REGION_NONE

/var/const/access_bearcat_inf_captain = "ACCESS_BEARCAT_CAPTAIN" //999
/datum/access/bearcat_captain
	id = access_bearcat_inf_captain
	desc = "FTU Captain"
	region = ACCESS_REGION_NONE

/obj/item/card/id/bearcat
	access = list(access_bearcat_inf)

/obj/item/card/id/bearcat_captain
	access = list(access_bearcat_inf, access_bearcat_inf_captain)

/obj/machinery/power/apc/derelict/bearcat
	req_access = list(access_bearcat_inf)

/obj/machinery/door/airlock/autoname/bearcat

/obj/machinery/door/airlock/autoname/engineering/bearcat

/obj/machinery/door/airlock/autoname/command/bearcat

/obj/structure/closet/secure_closet/engineering_electrical/bearcat
	req_access = list(access_bearcat_inf)

/obj/structure/closet/secure_closet/engineering_welding/bearcat
	req_access = list(access_bearcat_inf)

/obj/structure/closet/secure_closet/freezer/fridge/bearcat
	req_access = list(access_bearcat_inf)

/obj/structure/closet/secure_closet/freezer/meat/bearcat
	req_access = list(access_bearcat_inf)

/obj/machinery/vending/engineering/bearcat
	req_access = list(access_bearcat_inf)

/obj/machinery/vending/tool/bearcat
	req_access = list(access_bearcat_inf)

/obj/machinery/suit_storage_unit/engineering/salvage/bearcat
	req_access = list(access_bearcat_inf)
