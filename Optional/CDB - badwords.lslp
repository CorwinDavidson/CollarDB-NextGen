/*--------------------------------------------------------------------------------**
**  File: CDB - badwords                                                          **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/


//if list isn't blank, open listener on channel 0, with sub's key <== only for the first badword???

/*-------------//
//  VARIABLES  //
//-------------*/

string g_sBadWordAnim = "shock";
list g_lBadWords;
string g_sPenance = "pet is very sorry for her mistake";
integer g_iListener;

key g_kDialog;
string g_sSubMenu = "Badwords";
string g_sParentMenu = "AddOns";

string g_sIsEnabled = "badwordson=false";

//added to stop abdword anim only if it was started by using a badword
integer g_iHasSworn = FALSE;

integer g_iRedisplayMenu = FALSE;

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();


/*---------------//
//  FUNCTIONS    //
//---------------*/

integer Enabled()
{
    integer iIndex = llSubStringIndex(g_sIsEnabled, "=");
    string sValue = llGetSubString(g_sIsEnabled, iIndex + 1, llStringLength(g_sIsEnabled) - 1);
    if(sValue == "true")
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

DialogBadwords(key kID)
{
    string sText;
    list lButtons = ["List Words", "Clear ALL", "Say Penance"];
    if(Enabled())
    {
        lButtons += ["OFF"];
        sText += "Badwords are turned ON.\n";
    }
    else
    {
        lButtons += ["ON"];
        sText += "Badwords are turned OFF.\n";
    }
    sText += "'List Words' show you all badwords.\n";
    sText += "'Clear ALL' will delete all set badwords.\n";
    sText += "'Say Penance' will tell you the current penance phrase.\n";
    sText += "'Quick Help' will give you a brief help how to add or remove badwords.\n";
    lButtons += ["Quick Help"];
    g_kDialog=Dialog(kID, sText, lButtons, [UPMENU],0);
}

DialogHelp(key kID)
{
    string sMessage = "Usage of Badwords.\n";
    sMessage += "Put in front of each command your subs prefix then use them as followed:\n";
    sMessage += "badword <badword> where <badword> is the word you want to add.\n";
    sMessage += "rembadword <badword> where <badword> is the word you want to remove.\n";
    sMessage += "penance <what your sub has to say to get release from the badword anim.\n";
    sMessage += "badwordsanim <anim name> , make sure the animation is inside the collar.";
    g_kDialog=Dialog(kID, sMessage, ["Ok"], [], 0);
}

ListenControl()
{
    if(Enabled())
    {
        if (llGetListLength(g_lBadWords))
        {
            g_iListener = llListen(0, "", g_kWearer, "");
        }
    }
    else
    {
        llListenRemove(g_iListener);
    }
}

string DePunctuate(string sStr)
{
    string sLastChar = llGetSubString(sStr, -1, -1);
    if (sLastChar == "," || sLastChar == "." || sLastChar == "!" || sLastChar == "?")
    {
        sStr = llGetSubString(sStr, 0, -2);
    }
    return sStr;
}

integer HasSwear(string sStr)
{
    sStr = llToLower(sStr);
    list lWords = llParseString2List(sStr, [" "], []);
    integer n;
    for (n = 0; n < llGetListLength(lWords); n++)
    {
        string sWord = llList2String(lWords, n);
        sWord = DePunctuate(sWord);

        if (llListFindList(g_lBadWords, [sWord]) != -1)
        {
            return TRUE;
        }
    }
    return FALSE;
}

integer Contains(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return 0 <= llSubStringIndex(sHayStack, sNeedle);
}

string WordPrompt()
{
    string sName = llKey2Name(g_kWearer);
    string sPrompt = sName + " is forbidden from saying ";
    integer iLength = llGetListLength(g_lBadWords);
    if (!iLength)
    {
        sPrompt = sName + " is not forbidden from saying anything.";
    }
    else if (iLength == 1)
    {
        sPrompt += llList2String(g_lBadWords, 0);
    }
    else if (iLength == 2)
    {
        sPrompt += llList2String(g_lBadWords, 0) + " or " + llList2String(g_lBadWords, 1);
    }
    else
    {
        sPrompt += llDumpList2String(llDeleteSubList(g_lBadWords, -1, -1), ", ") + ", or " + llList2String(g_lBadWords, -1);
    }


    sPrompt += "\nThe penance phrase to clear the punishment anim is '" + g_sPenance + "'.";
    return sPrompt;
}

string right(string sSrc, string sDivider) {
    integer iIndex = llSubStringIndex( sSrc, sDivider );
    if(~iIndex)
        return llDeleteSubString( sSrc, 0, iIndex + llStringLength(sDivider) - 1);
    return sSrc;
}

/*---------------//
//  HANDLERS     //
//---------------*/

// pragma inline
HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SETTING_RESPONSE)
    {

        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);
        if(sToken == "badwordson")
        {
            g_sIsEnabled = "badwordson" + "=" + sValue;
            ListenControl();
        }
        if (sToken == "badwordsanim")
        {
            g_sBadWordAnim = sValue;
        }
        else if (sToken == "badwords")
        {
            g_lBadWords = llParseString2List(llToLower(sValue), ["~"], []);
            ListenControl();
        }
        else if (sToken == "penance")
        {
            g_sPenance = sValue;
        }
    }
}

// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        if(kID == g_kDialog)
        {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = (key)llList2String(lMenuParams, 0);
            string sMessage = llList2String(lMenuParams, 1);
            integer iPage = (integer)llList2String(lMenuParams, 2);
            if(sMessage == "Ok")
            {
                DialogBadwords(kAv);
            }
            if (sMessage == UPMENU)
            {    //give kID the parent menu
                llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
            }
            else if(sMessage == "Clear ALL")
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "badwords clearall", kAv);
            }
            else if(sMessage == "ON")
            {
                g_iRedisplayMenu = TRUE;
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "badwords on", kAv);

            }
            else if(sMessage == "OFF")
            {
                g_iRedisplayMenu = TRUE;
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "badwords off", kAv);
            }
            else if(sMessage == "List Words")
            {
                DialogBadwords(kAv);
                Notify(kAv, "Badwords are: " + llDumpList2String(g_lBadWords, " or "),FALSE);
            }
            else if(sMessage == "Say Penance")
            {
                DialogBadwords(kAv);
                Notify(kAv, "The penance phrase to release the sub from the punishment anim is:\n" + g_sPenance,FALSE);
            }
            else if(sMessage == "Quick Help")
                DialogHelp(kAv);

        }
    }
}

// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == MENU_SUBMENU)
    {
        if (sStr == g_sSubMenu)
        {
            DialogBadwords(kID);
        }
    }
    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }
    /*
    else if (iNum == MENU_RESPONSE)
    {
        list lParts = llParseString2List(sStr, ["|"], []);
        if (llList2String(lParts, 0) == g_sSubMenu)
        {//someone wants to stick something in our menu
            string button = llList2String(lParts, 1);
            if (llListFindList(g_lButtons, [button]) == -1)
            {
                g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
            }
        }
    }
    */
}

// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER && sStr == "settings")
    {
        Notify(kID, "Bad Words: " + llDumpList2String(g_lBadWords, ", "),FALSE);
        Notify(kID, "Bad Word Anim: " + g_sBadWordAnim,FALSE);
        Notify(kID, "Penance: " + g_sPenance,FALSE);
    }
    else if(iNum > COMMAND_OWNER && iNum <= COMMAND_EVERYONE)
    {
        if(sCommand == "badwords")
        {
            Notify(kID, "Sorry, only the owner can toggle badwords.",FALSE);
        }
    }
    else if (iNum == COMMAND_OWNER)
    {
        if(sStr == "badwords")
        {
            DialogBadwords(kID);
        }
        else if (sCommand == "badword")
        {
            //support owner adding words
            integer iOldLength = llGetListLength(g_lBadWords);
            list lNewBadWords = llDeleteSubList(llParseString2List(sStr, [" "], []), 0, 0);
            integer n;
            integer iLength = llGetListLength(lNewBadWords);
            for (n = 0; n < iLength; n++)
            {  //add new swear if not already in list
                string sNew = llList2String(lNewBadWords, n);
                sNew = DePunctuate(sNew);
                sNew = llToLower(sNew);
                if (llListFindList(g_lBadWords, [sNew]) == -1)
                {
                    g_lBadWords += [sNew];
                }
            }
            integer iNewLength = llGetListLength(g_lBadWords);
            if(!iOldLength && iNewLength)
            {
                g_sIsEnabled = "badwordson=true";
                llMessageLinked(LINK_SET, SETTING_SAVE, g_sIsEnabled, NULL_KEY);
            }
            //save to database
            llMessageLinked(LINK_SET, SETTING_SAVE, "badwords=" + llDumpList2String(g_lBadWords, "~"), NULL_KEY);
            ListenControl();
            Notify(kID, WordPrompt(),TRUE);
        }
        else if (sCommand == "badwordsanim")
        {
            //Get all text after the command, strip spaces from start and end
            string sAnim = right(sStr, sCommand);
            sAnim = llStringTrim(sAnim, STRING_TRIM);

            if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION)
            {
                g_sBadWordAnim = sAnim;
                //Debug(g_sBadWordAnim);
                llMessageLinked(LINK_SET, SETTING_SAVE, "badwordsanim=" + g_sBadWordAnim, NULL_KEY);
                Notify(kID, "Punishment anim for bad words is now '" + g_sBadWordAnim + "'.",FALSE);
            }
            else
            {
                Notify(kID, llList2String(lParams, 1) + " is not a valid animation name.",FALSE);
            }
        }
        else if (sCommand == "penance")
        {
            string sPenance = llDumpList2String(llDeleteSubList(lParams, 0, 0), " ");
            if (sPenance == "")
            {
                Notify(kID, "The penance phrase to release the sub from the punishment anim is:\n" + g_sPenance,FALSE);
            }
            else
            {
                g_sPenance = llStringTrim(sPenance, STRING_TRIM);
                llMessageLinked(LINK_SET, SETTING_SAVE, "penance=" + g_sPenance, NULL_KEY);
                string sPrompt = WordPrompt();
                Notify(kID, sPrompt,TRUE);
            }

        }
        else if (sCommand == "rembadword")
        {    //support owner adding words
            list remg_lBadWords = llDeleteSubList(llParseString2List(sStr, [" "], []), 0, 0);
            integer n;
            integer iLength = llGetListLength(remg_lBadWords);
            for (n = 0; n < iLength; n++)
            {  //add new swear if not already in list
                string rem = llList2String(remg_lBadWords, n);
                integer iIndex = llListFindList(g_lBadWords, [rem]);
                if (iIndex != -1)
                {
                    g_lBadWords = llDeleteSubList(g_lBadWords, iIndex, iIndex);
                }
            }
            //save to sDatabase
            llMessageLinked(LINK_SET, SETTING_SAVE, "badwords=" + llDumpList2String(g_lBadWords, "~"), NULL_KEY);
            ListenControl();
            Notify(kID, WordPrompt(),TRUE);
        }
        else if (sCommand == "badwords")
        {
            if(sValue == "on")
            {
                if(llGetListLength(g_lBadWords))
                {
                    g_sIsEnabled = "badwordson=true";
                    llMessageLinked(LINK_SET, SETTING_SAVE, g_sIsEnabled, NULL_KEY);
                    //llMessageLinked(LINK_SET, SETTING_SAVE, "badwords=" + g_sIsEnabled, NULL_KEY);
                    ListenControl();
                    Notify(kID, "Badwords are now turned on for: " + llDumpList2String(g_lBadWords, "~"),FALSE);
                }
                else
                    Notify(kID, "There are no badwords set. Define at least one badword before turning it on.",FALSE);

            }
            else if(sValue == "off")
            {
                g_sIsEnabled = "badwordson=false";
                llMessageLinked(LINK_SET, SETTING_SAVE, g_sIsEnabled, NULL_KEY);
                ListenControl();
                Notify(kID, "Badwords are now turned off.",FALSE);
            }
            else if(sValue == "clearall")
            {
                g_lBadWords = [];
                g_sIsEnabled = "badwordson=false";
                llMessageLinked(LINK_SET, SETTING_SAVE, g_sIsEnabled, NULL_KEY);
                llMessageLinked(LINK_SET, SETTING_SAVE, "badwords=", NULL_KEY);
                ListenControl();
                DialogBadwords(kID);
                Notify(kID, "You cleared the badword list and turned it off.",FALSE);
            }
            if (g_iRedisplayMenu)
            {
                g_iRedisplayMenu = FALSE;
                DialogBadwords(kID);

            }

        }
    }
    else if(iNum == COMMAND_SAFEWORD)
    { // safeword disables badwords !
        g_sIsEnabled = "badwords=false";
        llMessageLinked(LINK_SET, SETTING_SAVE, g_sIsEnabled, NULL_KEY);
        ListenControl();
    }    
}

/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {
        g_kWearer=llGetOwner();
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            HandleMENU(iSender,iNum,sStr,kID); 
        }
        else if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG_REQUEST))
        {
            HandleDIALOG(iSender,iNum,sStr,kID);
        }        
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_SAFEWORD))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
    } 
    
    listen(integer iChannel, string sName, key kID, string sMessage)
    {
        //release anim if penance & play anim if swear
        if (iChannel == 0)
        {
            if ((~(integer)llSubStringIndex(llToLower(sMessage), llToLower(g_sPenance))) && g_iHasSworn )
            { //stop anim
                llMessageLinked(LINK_SET, ANIM_STOP, g_sBadWordAnim, NULL_KEY);
                Notify(g_kWearer, "Penance accepted.",FALSE);
                g_iHasSworn = FALSE;
            }
            else if (Contains(sMessage, "rembadword"))
            {//subs could theoretically circumvent this feature by sticking "rembadowrd" in all chat, but it doesn't seem likely to happen often
                return;
            }
            else if (HasSwear(sMessage))
            {   //start anim
                llMessageLinked(LINK_SET, ANIM_START, g_sBadWordAnim, NULL_KEY);
                llWhisper(0, llList2String(llParseString2List(llKey2Name(g_kWearer), [" "], []), 0) + " has said a bad word and is being punished.");
                g_iHasSworn = TRUE;
            }
        }
    }

}