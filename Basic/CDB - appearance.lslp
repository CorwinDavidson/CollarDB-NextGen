/*--------------------------------------------------------------------------------**
**  File: CDB - appearance                                                        **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//CollarDB - appearance
//handle appearance menu
//handle saving position on detach, and restoring it on SETTING_response

/*-------------//
//  VARIABLES  //
//-------------*/

string g_sSubMenu = "Appearance";
string g_sParentMenu = "Main";

string g_sSubMenu2 = "FloatText";
string g_sParentMenu2 = "AddOns";

//-------------------------------------
string g_sHoverLinkName = "FloatText";
string g_sHoverTextDBToken = "hovertext";

list g_lHoverTextSettings = [];

integer g_iHoverLink=0;
integer g_iHoverLastRank = 0;
integer g_iHoverOn = FALSE;

string g_sHoverText;

vector g_vPrimScale = <0.02,0.02,0.5>; // prim size, initial value (z - text offset height)
vector g_vPrimSlice = <0.490,0.51,0.0>; // prim slice

string SET = "Set Title";
string UP = "↑ Up";
string DN = "↓ Down";
string ON = "☒ Show";
string OFF = "☐ Show";
string HELP = "Help";

//---------------------------------

list g_lMenuIDs;//3-strided list of avkey, dialogid, menuname
integer g_iMenuStride = 3;

integer g_iRemenu;

string POSMENU = "Position";
string ROTMENU = "Rotation";
string SIZEMENU = "Size";
string TEXTUREMENU = "Textures";
string COLORMENU = "Colors";
string HIDEMENU = "Hide/Show";
string ELEMENTMENU;

list g_lLocalButtons = [POSMENU, ROTMENU, SIZEMENU, TEXTUREMENU , COLORMENU, HIDEMENU]; //[POSMENU, ROTMENU];
list g_lRemoteButtons;

float g_fSmallNudge=0.0005;
float g_fMediumNudge=0.005;
float g_fLargeNudge=0.05;

float g_fNudge=0.005; // g_fMediumNudge;
float g_fRotNudge;

// SizeScale
list SIZEMENU_BUTTONS = [ "-1%", "-2%", "-5%", "-10%", "+1%", "+2%", "+5%", "+10%", "100%" ]; // buttons for menu
list g_lSizeFactors = [-0.01, -0.02, -0.05, -0.10, 0.01, 0.02, 0.05, 0.10, 999.0]; // actual size factors
float g_fScaleFactor = 1.00; // the size on rez is always regarded as 100% to preven problem when scaling an item +10% and than - 10 %, which would actuall lead to 99% of the original size

string TICKED = "(*)";
string UNTICKED = "( )";

string APPLOCK = "Lock Appearance";
integer g_iAppLock = FALSE;
string g_sAppLockToken = "AppLock";

// Integrated Alpha / Color / Texture

list g_lHideElements = [];
list g_lAlphaSettings = [];
string g_sAlphaDBToken = "elementalpha";

list g_lColorElements = [];
list g_lColorSettings = [];
string g_sColorDBToken = "colorsettings";
list g_lCategories = ["Blues", "Browns", "Grays", "Greens", "Purples", "Reds", "Yellows"];

list g_lTextureElements = [];
list g_lTextureSettings = [];
string g_sTextureDBToken = "textures";


string g_sCurrentElement = "";
string g_sCurrentCategory = "";

string HIDE = "Hide ";
string SHOW = "Show ";
string SHOWN = "Shown";
string HIDDEN = "Hidden";
string ALL = "All";
string g_sType = "";


key g_kUser;
key g_kHTTPID;

list g_lColors;
integer g_iStridelength = 2;
integer g_iPage = 0;
integer g_iMenuPage;
integer g_iPagesize = 10;
integer g_iLength;
list g_lNewButtons;

string g_sSETTING_Url = "http://data.collardb.com/"; //defaul OC url, can be changed in defaultsettings notecard and wil be send by settings script if changed

// Textures in Notecard for Non Full Perm textures
key g_ktexcardID;
string g_noteName = "";
integer g_noteLine;
list g_textures = [];
list g_read = [];

// Integrated Alpha / Color / Texture
$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();


/*---------------//
//  FUNCTIONS    //
//---------------*/


// Integrated Alpha / Color / Texture

BuildElementList()
{
    g_lColorElements = [];
    g_lTextureElements = [];
    g_lHideElements = [];
    
    integer n;
    integer iLinkCount = llGetNumberOfPrims();

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        list lElement = llParseString2List(ElementType(n),["|"],[]);
        string sElement = llList2String(lElement,0);
        if (!(~(integer)llListFindList(g_lColorElements, [sElement])) && !(~(integer)llListFindList(lElement, ["nocolor"])))
            g_lColorElements += [sElement];
        if (!(~(integer)llListFindList(g_lTextureElements, [sElement])) && !(~(integer)llListFindList(lElement, ["notexture"])))
            g_lTextureElements += [sElement];
        if (!(~(integer)llListFindList(g_lHideElements, [sElement])) && !(~(integer)llListFindList(lElement, ["nohide"])))
            g_lHideElements += [sElement];
    }
    g_lColorElements = llListSort(g_lColorElements, 1, TRUE);
    g_lTextureElements = llListSort(g_lTextureElements, 1, TRUE);    
    g_lHideElements = llListSort(g_lHideElements, 1, TRUE);
}

ElementMenu(key kAv,list lElements)
{
    g_sCurrentElement = "";
    string sPrompt = "Pick which part of the collar you would like to " + g_sType;
    g_lButtons = [];

    if (g_sType == "hide or show")
    {
        integer n;
        integer iStop = llGetListLength(lElements);
        for (n = 0; n < iStop; n++)
        {
            string sElement = llList2String(lElements, n);
            integer iIndex = llListFindList(g_lAlphaSettings, [llToLower(sElement)]);
            if (iIndex == -1)
            {
                g_lButtons += HIDE + sElement;
            }
            else
            {
                float fAlpha = (float)llList2String(g_lAlphaSettings, iIndex + 1);
                if (fAlpha)
                {
                    g_lButtons += HIDE + sElement;
                }
                else
                {
                    g_lButtons += SHOW + sElement;
                }
            }
        }
        g_lButtons += [SHOW + ALL, HIDE + ALL];    
    }
    else
    {
        g_lButtons = llListSort(lElements, 1, TRUE);
    }
    key kMenuID = Dialog(kAv, sPrompt, g_lButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, ELEMENTMENU);    
}

CategoryMenu(key kAv)
{
    //give kAv a dialog with a list of color cards
    string sPrompt = "Pick a Color.";
    key kMenuID = Dialog(kAv, sPrompt, g_lCategories, [UPMENU],0);
    MenuIDAdd(kAv, kMenuID, COLORMENU);
}

ColorMenu(key kAv)
{
    string sPrompt = "Pick a Color.";
    list g_lButtons = llList2ListStrided(g_lColors,0,-1,2);
    key kMenuID = Dialog(kAv, sPrompt, g_lButtons, [UPMENU],0);
    MenuIDAdd(kAv, kMenuID, COLORMENU);
}

TextureMenu(key kAv, integer iPage)
{
    //create a list
    list lButtons;
    string sPrompt = "Choose the texture to apply.";

    integer iNumTex = llGetInventoryNumber(INVENTORY_TEXTURE);
    integer n;
    for (n=0;n<iNumTex;n++)
    {
        string sName = llGetInventoryName(INVENTORY_TEXTURE,n);
        lButtons += [sName];
    }
    integer iNoteTex = llGetListLength(g_textures);
    for (n=0;n<iNoteTex;n=n+2)
    {
        string sName = llList2String(g_textures,n);
        lButtons += [sName];
    }
    key kMenuID = Dialog(kAv, sPrompt, lButtons, [UPMENU], iPage);
    MenuIDAdd(kAv, kMenuID, TEXTUREMENU);
}

string ElementType(integer iLinkNumber)
{
    string sDesc = (string)llGetLinkPrimitiveParams(iLinkNumber, [PRIM_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to
    //not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    string type = llList2String(lParams, 0) + "|";
    if (type == g_sHoverLinkName + "|") 
    {
        if (llList2Integer(llGetLinkPrimitiveParams(iLinkNumber,[PRIM_TYPE]),0)==PRIM_TYPE_BOX){
            g_iHoverLink = iLinkNumber;
        } else {
            llSetLinkPrimitiveParamsFast(iLinkNumber,[PRIM_TEXT,"",<0,0,0>,0]);
        }    
    }    
    if (sDesc == "" || sDesc == " " || sDesc == "(No Description)")
    {
        type += "nocolor|notexture|nohide";
    }
    else if ((~(integer)llListFindList(lParams, ["nocolor"])) || (~(integer)llListFindList(lParams, ["notexture"])) || (~(integer)llListFindList(lParams, ["nohide"])))
    {
        if (~(integer)llListFindList(lParams, ["nocolor"]))
        {
            type += "nocolor|";
        }
        else
        {
            type += "|";
        }
        if (~(integer)llListFindList(lParams, ["notexture"]))
        {
            type += "notexture|";
        }
        else
        {
            type += "|";
        }        
        if (~(integer)llListFindList(lParams, ["nohide"]))
        {
            type += "nohide|";
        }
        else
        {
            type += "|";
        }                
    }        
    
    return type;
}

MenuIDAdd(key kAv, key kMenuID, string sMenu)
{
    integer iMenuIndex = llListFindList(g_lMenuIDs, [kAv]);
    list lAddMe = [kAv, kMenuID, sMenu];
    if (iMenuIndex == -1)
    {
        g_lMenuIDs += lAddMe;
    }
    else
    {
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, lAddMe, iMenuIndex, iMenuIndex + g_iMenuStride - 1);
    }
}

loadNoteCards(string param)
{
    if (g_noteName != "" &&  param == "EOF")
    {
        g_read += [g_noteName];
        g_textures = llListSort(g_textures,2,TRUE);
    }
        
    if (g_noteName == "" &&  param == "")
    {
        g_read = [];
        g_textures = [];
    }
        
    if ((g_noteName != "" &&  param == "EOF") || (g_noteName == "" &&  param == ""))
    {
        integer iNumNote = llGetInventoryNumber(INVENTORY_NOTECARD);
        integer n;
        for (n=0;n<iNumNote;n++)
        {
            string sName = llGetInventoryName(INVENTORY_NOTECARD,n);
            if (startswith(llToLower(sName),"~cdbt_"))
            {
                if (llListFindList(g_read,[sName]) == -1)
                {
                    n=iNumNote;                
                    g_noteName = sName;
                    g_noteLine = 0;
                    g_ktexcardID = llGetNotecardLine(g_noteName, g_noteLine);
                }
            }
            
        }    
    }
}


// Integrated Alpha / Color / Texture

LoadHoverTextSettings()
{
    integer n;
    string sToken;
    string sValue;
    integer iItemCount = llGetListLength(g_lHoverTextSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        sToken = llList2String(g_lHoverTextSettings,n);
        sValue = llList2String(g_lHoverTextSettings,n+1);
        if(sToken == "text")
        {
            g_sHoverText = sValue;
        }
        else if(sToken == "on") 
        {
            g_iHoverOn = (integer)sValue;
        }
        else if(sToken == "height") 
        { 
            g_vPrimScale.z = (float)sValue;
        }
        else if(sToken == "lastrank")
        {
            g_iHoverLastRank = (integer)sValue;
        }
    }
}

HoverMenu(key kAv)
{
    string ON_OFF ;
    string sPrompt;
    key kMenuID;
    if (g_iHoverLink == -1) {
        sPrompt="\nThis design is missing a FloatText box. FloatText disabled.";
        kMenuID = Dialog(kAv, sPrompt, [], [UPMENU],0);
    } else {
        sPrompt = "\nCurrent Title: " + g_sHoverText ;
        if(g_iHoverOn == TRUE) ON_OFF = ON ;
        else ON_OFF = OFF ;
        kMenuID = Dialog(kAv, sPrompt, [SET,UP,DN,ON_OFF], [HELP,UPMENU],0);
    }
    MenuIDAdd(kAv, kMenuID, g_sSubMenu2); 
}

RotMenu(key kAv)
{
    string sPrompt = "Adjust the collar rotation.";
    list lMyButtons = ["tilt up", "right", "tilt left", "tilt down", "left", "tilt right"];// ria change
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, ROTMENU);
}

PosMenu(key kAv)
{
    string sPrompt = "Adjust the collar position:\nChoose the size of the nudge (S/M/L), and move the collar in one of the three directions (X/Y/Z).\nCurrent nudge size is: ";
    list lMyButtons = ["left", "up", "forward", "right", "down", "backward"];// ria iChange
    if (g_fNudge!=g_fSmallNudge) lMyButtons+=["Nudge: S"];
    else sPrompt += "Small.";
    if (g_fNudge!=g_fMediumNudge) lMyButtons+=["Nudge: M"];
    else sPrompt += "Medium.";
    if (g_fNudge!=g_fLargeNudge) lMyButtons+=["Nudge: L"];
    else sPrompt += "Large.";
    
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, POSMENU);
}

SizeMenu(key kAv)
{
    string sPrompt = "Adjust the collar scale. It is based on the size the collar has on rezzing. You can change back to this size by using '100%'.\n\nCurrent size: " + (string)llRound(g_fScaleFactor * 100.0) + "%\n\nATTENTION! May break the design of collars. Make a copy of the collar before using!";
    key kMenuID = Dialog(kAv, sPrompt, SIZEMENU_BUTTONS, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, SIZEMENU);    
}

DoMenu(key kAv)
{
    list lMyButtons;
    string sPrompt;
    if (g_iAppLock)
    {
        sPrompt = "The appearance of the collar has be locked. To modified it a owner has to unlock it.";
        lMyButtons = [TICKED + APPLOCK];
    }
    else
    {
        sPrompt = "Which aspect of the appearance would you like to modify? Owners can lock the appearance of the collar, so it cannot be changed at all.\n";
    
        lMyButtons = [UNTICKED + APPLOCK];
        lMyButtons += llListSort(g_lLocalButtons + g_lRemoteButtons, 1, TRUE);
    }
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, g_sSubMenu);   
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

        if (sToken == g_sAppLockToken)
        {
            g_iAppLock = (integer)sValue;
        }
        else if (sToken == g_sHoverTextDBToken)
        {
            g_lHoverTextSettings = llParseString2List(sValue, ["~"], []);
            LoadHoverTextSettings();
        }         
    }
    if (iNum == SETTING_SAVE)
    {
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);    
        if (sToken == g_sHoverTextDBToken)
        {
            g_lHoverTextSettings = llParseString2List(sValue, ["~"], []);
            LoadHoverTextSettings();
        }
    }
}

// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
        if (iMenuIndex != -1)
        {
            //got a menu response meant for us.  pull out values
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = (key)llList2String(lMenuParams, 0);          
            string sMessage = llList2String(lMenuParams, 1);                                         
            integer iPage = (integer)llList2String(lMenuParams, 2);
            string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
            //remove stride from g_lMenuIDs
            //we have to subtract from the index because the dialog id comes in the middle of the stride
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                  
            if (sMenuType == g_sSubMenu)
            {
                if (sMessage == UPMENU)
                {
                    //give kID the parent menu
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                }
                else if(llGetSubString(sMessage, llStringLength(TICKED), -1) == APPLOCK)
                {
                        if(llGetSubString(sMessage, 0, llStringLength(TICKED) - 1) == TICKED)
                        {
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "applock 0", kAv);
                        }
                        else
                        {
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "applock 1", kAv);
                        }

                    }
                else if (~llListFindList(g_lLocalButtons, [sMessage]))
                {
                    //we got a response for something we handle locally
                    if (sMessage == POSMENU)
                    {
                        PosMenu(kAv);
                    }
                    else if (sMessage == ROTMENU)
                    {
                        RotMenu(kAv);
                    }
                    else if (sMessage == SIZEMENU)
                    {
                        SizeMenu(kAv);
                    }
                    else if (sMessage == COLORMENU)
                    {
                        g_sCurrentElement = "";
                        ELEMENTMENU = COLORMENU;
                        g_sType = "color";
                        ElementMenu(kAv, g_lColorElements);
                    }
                    else if (sMessage == HIDEMENU)
                    {
                        g_sCurrentElement = "";
                        ELEMENTMENU = HIDEMENU;
                        g_sType = "hide or show";
                        ElementMenu(kAv, g_lHideElements);
                    }
                    else if (sMessage == TEXTUREMENU)
                    {
                        g_sCurrentElement = "";
                        ELEMENTMENU = TEXTUREMENU;
                        g_sType = "texture";
                        ElementMenu(kAv, g_lTextureElements);
                    }                        
                }
                else if (~llListFindList(g_lRemoteButtons, [sMessage]))
                {
                    //we got a submenu selection
                    llMessageLinked(LINK_SET, MENU_SUBMENU, sMessage, kAv);
                }                                
            }
            else if (sMenuType == g_sSubMenu2)
            {
                if (sMessage == SET) 
                {
                    llMessageLinked(LINK_ROOT, POPUP_HELP, "\nTo set a title via chat command, say _PREFIX_title followed by the title you wish to set.\n\nExample: _PREFIX_text I have text above my head!", kAv);   
                } 
                else if (sMessage == UPMENU) 
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu2, kAv);
                } 
                else 
                {
                    if (sMessage == HELP) 
                    {
                        //popup help on how to set label
                        llMessageLinked(LINK_ROOT, POPUP_HELP, "\nTo set a title via chat command, say _PREFIX_title followed by the title you wish to set.\n\nExample: _PREFIX_text I have text above my head!", kAv);
                    } 
                    else if (sMessage == UP) 
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "textup", kAv);
                    }
                    else if (sMessage == DN)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "textdown", kAv);
                    }
                    else if (sMessage == OFF)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "texton", kAv);
                        g_iHoverOn = TRUE;
                    }
                    else if (sMessage == ON)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "textoff", kAv);
                        g_iHoverOn = FALSE;
                    }
                    HoverMenu(kAv);
                }
            }
            else if (sMenuType == POSMENU)
            {
                if (sMessage == UPMENU)
                {
                    DoMenu(kAv);
                    return;
                }
                else if (llGetAttached())
                {
                    vector vNudge = <0,0,0>;
                    if (sMessage == "left")
                    {
                        vNudge.x = g_fNudge;
                    }
                    else if (sMessage == "up")
                    {
                        vNudge.y = g_fNudge;                
                    }
                    else if (sMessage == "forward")
                    {
                        vNudge.z = g_fNudge;                
                    }            
                    else if (sMessage == "right")
                    {
                        vNudge.x = -g_fNudge;                
                    }            
                    else if (sMessage == "down")
                    {
                        vNudge.y = -g_fNudge;                    
                    }            
                    else if (sMessage == "backward")
                    {
                        vNudge.z = -g_fNudge;                
                    }                            
                    llMessageLinked(LINK_SET, APPEARANCE_POSITION, (string)vNudge, kAv);                        
                    
                    if (sMessage == "Nudge: S")
                    {
                        g_fNudge=g_fSmallNudge;
                    }
                    else if (sMessage == "Nudge: M")
                    {
                        g_fNudge=g_fMediumNudge;                
                    }
                    else if (sMessage == "Nudge: L")
                    {
                        g_fNudge=g_fLargeNudge;                
                    }                        
                }
                else
                {
                    Notify(kAv, "Sorry, position can only be adjusted while worn",FALSE);
                }
                PosMenu(kAv);                    
            }
            else if (sMenuType == ROTMENU)
            {
                if (sMessage == UPMENU)
                {
                    DoMenu(kAv);
                    return;
                }
                else if (llGetAttached())
                {
                    vector vNudge = <0,0,0>;
                    if (sMessage == "tilt up")
                    {
                        vNudge.x = g_fRotNudge;
                    }
                    else if (sMessage == "right")
                    {
                        vNudge.y = g_fRotNudge;                
                    }
                    else if (sMessage == "tilt left")
                    {
                        vNudge.z = g_fRotNudge;               
                    }            
                    else if (sMessage == "tilt down")
                    {
                        vNudge.x = -g_fRotNudge;                
                    }            
                    else if (sMessage == "left")
                    {
                        vNudge.y = -g_fRotNudge;                  
                    }            
                    else if (sMessage == "tilt right")
                    {
                        vNudge.z = -g_fRotNudge;               
                    }
                    llMessageLinked(LINK_SET, APPEARANCE_ROTATION, (string)vNudge, kAv);                        
                }
                else
                {
                    Notify(kAv, "Sorry, position can only be adjusted while worn", FALSE);
                }
                RotMenu(kAv);                     
            }
            else if (sMenuType == SIZEMENU)
            {
                if (sMessage == UPMENU)
                {
                    DoMenu(kAv);
                    return;
                }
                else
                {
                    integer iMenuCommand = llListFindList(SIZEMENU_BUTTONS, [sMessage]);
                    if (iMenuCommand != -1)
                    {
                        float fSizeFactor = llList2Float(g_lSizeFactors, iMenuCommand);
                        if (fSizeFactor == 999.0)
                        {
                            // ResSize requested
                            if (g_fScaleFactor == 1.0)
                            {
                                Notify(kAv, "The collar is already at rez size, resizing canceled.", FALSE); 
                            }
                            else
                            {
                                llMessageLinked(LINK_SET, APPEARANCE_SIZE, "1.00§" + (string)TRUE, kAv);
                            }
                        }
                        else
                        {
                            llMessageLinked(LINK_SET, APPEARANCE_SIZE, (string)(g_fScaleFactor + fSizeFactor) + "§" + (string)FALSE, kAv);
                        }
                    }
                }
            }
            else if (sMenuType == COLORMENU)
            {
                if (sMessage == UPMENU)
                {
                    if (g_sCurrentElement == "")
                    {
                        //main menu
                        llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                    }
                    else if (g_sCurrentCategory == "")
                    {
                        g_sCurrentElement = "";
                        ELEMENTMENU = COLORMENU;
                        g_sType = "color";
                        ElementMenu(kAv, g_lColorElements);
                    }
                    else
                    {
                        g_sCurrentCategory = "";
                        CategoryMenu(kAv);
                    }
                }
                else if (g_sCurrentElement == "")
                {
                    g_sCurrentElement = sMessage;
                    g_iPage = 0;
                    g_sCurrentCategory = "";
                    CategoryMenu(kAv);
                }

                else if (g_sCurrentCategory == "")
                {
                    g_lColors = [];
                    g_sCurrentCategory = sMessage;
                    g_iPage = 0;
                    g_kUser = kAv;
                    string sUrl = g_sSETTING_Url + "static/colors-" + g_sCurrentCategory + ".txt";
                    g_kHTTPID = llHTTPRequest(sUrl, [HTTP_METHOD, "GET"], "");
                }
                else if (~(integer)llListFindList(g_lColors, [sMessage]))
                {
                    integer iIndex = llListFindList(g_lColors, [sMessage]);
                    vector vColor = (vector)llList2String(g_lColors, iIndex + 1);
                    llMessageLinked(LINK_SET, APPEARANCE_COLOR, llToLower(g_sCurrentElement) + "§" + (string)vColor  + "§" + (string)TRUE, kAv);
                    ColorMenu(kAv);
                }
            
            }
            else if (sMenuType == HIDEMENU)
            {
                if (sMessage == UPMENU)
                {
                    if (g_sCurrentElement == "")
                    {
                        //main menu
                        llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                    }
                    else
                    {
                        g_sCurrentElement = "";
                        ELEMENTMENU = HIDEMENU;
                        g_sType = "hide or show";
                        ElementMenu(kAv, g_lHideElements);                            
                    }
                }
                else
                {
                    //get "Hide" or "Show" and element name
                    list lParams = llParseString2List(sMessage, [], [HIDE,SHOW]);
                    string sCmd = llList2String(lParams, 0);
                    string sElement = llToLower(llList2String(lParams, 1));
                    float fAlpha;
                    if (sCmd == HIDE)
                    {
                        fAlpha = 0.0;
                    }
                    else if (sCmd == SHOW)
                    {
                        fAlpha = 1.0;
                    }

                    if (sElement == ALL)
                    {
                        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, "all§" + (string)fAlpha + "§" + (string)TRUE, kAv);
                        g_lAlphaSettings = [];
                        integer n;
                        for (n = 0; n < llGetListLength(g_lHideElements); n++)
                        {
                            g_lAlphaSettings += [llToLower(llList2String(g_lHideElements,n))] + [fAlpha];
                        }                            
                    }
                    else if (sElement != "")//ignore empty element strings since they won't work anyway
                    {
                        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, sElement +"§" + (string)fAlpha + "§" + (string)TRUE, kAv);
                        integer iIndex2 = llListFindList(g_lAlphaSettings, [sElement]);
                        if (iIndex2 == -1)
                        {
                            g_lAlphaSettings += [sElement, fAlpha];
                        }
                        else
                        {
                            g_lAlphaSettings = llListReplaceList(g_lAlphaSettings, [fAlpha], iIndex2+ 1, iIndex2 + 1);
                        }                            
                    }
                    //SaveAlphaSettings();
                    g_sCurrentElement = "";
                    ELEMENTMENU = HIDEMENU;
                    g_sType = "hide or show";
                    ElementMenu(kAv, g_lHideElements);
                }
            }
            else if (sMenuType == TEXTUREMENU)
            {
                if (sMessage == UPMENU)
                {
                    if (g_sCurrentElement == "")
                    {
                        //main menu
                        llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                    }
                    else if (g_sCurrentCategory == "")
                    {
                        g_sCurrentElement = "";
                        ELEMENTMENU = TEXTUREMENU;
                        g_sType = "texture";
                        ElementMenu(kAv, g_lTextureElements);
                    }
                }
                else if (g_sCurrentElement == "")
                {
                    g_sCurrentElement = sMessage;
                    TextureMenu(kAv, iPage);
                }
                else
                {
                    //got a texture name
                    string sTex;
                    if (llListFindList(g_textures,[sMessage]) != -1)
                    {
                        sTex = llList2String(g_textures,llListFindList(g_textures,[sMessage]) + 1);
                    }
                    else
                    {
                        sTex = (string)llGetInventoryKey(sMessage);
                    }
                    //loop through links, setting texture if element type matches what we're changing
                    //root prim is 1, so start at 2
                    llMessageLinked(LINK_SET, APPEARANCE_TEXTURE, llToLower(g_sCurrentElement) +"§" + sTex + "§" + (string)TRUE, kAv);
                    TextureMenu(kAv, iPage);
                }                            
            }                
        }            
    }
    else if (iNum == DIALOG_TIMEOUT)
    {
        integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
        if (iMenuIndex != -1)
        {
            //remove stride from g_lMenuIDs
            //we have to subtract from the index because the dialog id comes in the middle of the stride
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                          
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
            g_iRemenu = TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "appearance",kID);
        }
        else if (sStr == g_sSubMenu2)
        {
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "floattext",kID);
//            llMessageLinked(LINK_ROOT, POPUP_HELP, "To set floating text , say _PREFIX_text followed by the text you wish to set.  \nExample: _PREFIX_text I have text above my head!", kID);
        }
    }
    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu2 + "|" + g_sSubMenu2, NULL_KEY);
    }
    else if (iNum == MENU_RESPONSE)
    {
        list lParts = llParseString2List(sStr, ["|"], []);
        if (llList2String(lParts, 0) == g_sSubMenu)
        {
            string button = llList2String(lParts, 1);
            if (llListFindList(g_lRemoteButtons, [button]) == -1)
            {
                g_lRemoteButtons = llListSort(g_lRemoteButtons + [button], 1, TRUE);
            }
        }
    }
}
// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
    {
        list lParams = llParseString2List(sStr, [" "], []);
        string sCommand = llToLower(llList2String(lParams, 0));
        string sValue = llToLower(llList2String(lParams, 1));
        string sValue2 = llToLower(llList2String(lParams, 2));        

        float fAlpha;
        if (sStr == "refreshmenu")
        {
            g_lButtons = [];
            g_lRemoteButtons = [];
            llMessageLinked(LINK_SET, MENU_REQUEST, g_sSubMenu, NULL_KEY);
        }
        else if (sStr == "appearance")
        {
            if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
            {
                Notify(kID,"You are not allowed to change the collar appearance.", FALSE);
                if (g_iRemenu) llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kID);
            }
            else DoMenu(kID);
            g_iRemenu=FALSE;
        }
        else if (sStr == "floattext")
        {
            if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
            {
                Notify(kID,"You are not allowed to change hover text.", FALSE);
                if (g_iRemenu) llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu2, kID);
            }
            else HoverMenu(kID);
            g_iRemenu=FALSE;
        }        
        else if (sStr == "rotation")
        {
            if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
            {
                Notify(kID,"You are not allowed to change the collar rotation.", FALSE);
            }
            else if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                DoMenu(kID);
            }
            else RotMenu(kID);
         }
        else if (sStr == "position")
        {
            if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
            {
                Notify(kID,"You are not allowed to change the collar position.", FALSE);
            }
            else if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                DoMenu(kID);
            }
            else PosMenu(kID);
        }
        else if (sStr == "size")
        {
            if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
            {
                Notify(kID,"You are not allowed to change the collar size.", FALSE);
            }
            else if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                DoMenu(kID);
            }
            else SizeMenu(kID);
        }
        else if (llGetSubString(sStr,0,6) == "applock")
        {
            if (iNum == COMMAND_OWNER)
            {
                if(llGetSubString(sStr, -1, -1) == "0")
                {
                    g_iAppLock = FALSE;
                    llMessageLinked(LINK_SET, SETTING_DELETE, g_sAppLockToken, NULL_KEY);
                    llMessageLinked(LINK_SET, COMMAND_OWNER, "lockappearance 0", kID);
                }
                else
                {
                    g_iAppLock = TRUE;
                    llMessageLinked(LINK_SET, SETTING_SAVE, g_sAppLockToken + "=1", NULL_KEY);
                    llMessageLinked(LINK_SET, COMMAND_OWNER, "lockappearance 1", kID);
                }
            }
            else
            {
                Notify(kID,"Only owners can use this option.",FALSE);
            }
            DoMenu(kID);
        }
        else if ((sCommand == "hide") || (sCommand == "show"))
        {
            if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
            }
            else
            {
                if (sCommand == "hide")
                {
                    fAlpha = 0.0;
                }
                else if (sCommand == "show")
                {
                    fAlpha = 1.0;                    
                }
                if ((sValue == "") || (sValue == "all"))
                {
                    llMessageLinked(LINK_SET, APPEARANCE_ALPHA, "all§" + (string)fAlpha + "§" + (string)TRUE, kID);

                    g_lAlphaSettings = [];
                    integer n;
                    for (n = 0; n < llGetListLength(g_lHideElements); n++)
                    {
                        g_lAlphaSettings += [llToLower(llList2String(g_lHideElements,n))] + [fAlpha];
                    }
                }
                else{
                     llMessageLinked(LINK_SET, APPEARANCE_ALPHA, sValue +"§" + (string)fAlpha + "§" + (string)TRUE, kID);
                    integer iIndex2 = llListFindList(g_lAlphaSettings, [sValue]);
                    if (iIndex2 == -1)
                    {
                        g_lAlphaSettings += [sValue, fAlpha];
                    }
                    else
                    {
                        g_lAlphaSettings = llListReplaceList(g_lAlphaSettings, [fAlpha], iIndex2+ 1, iIndex2 + 1);
                    }                
                }
            }
        }
        else if (sCommand == "colors")
        {
            if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
            }
            else
            {
                g_sCurrentElement = "";
                ELEMENTMENU = COLORMENU;
                g_sType = "color";
                ElementMenu(kID, g_lColorElements); 
            }            
        } 
        else if (sCommand == "setcolor")
        {
            if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
            }
            else
            {
                llMessageLinked(LINK_SET, APPEARANCE_COLOR, sValue + "§" + sValue2  + "§" + (string)TRUE, kID);
            }
        }          
        else if (sCommand == "textures")
        {
            if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
            }
            else
            {
                g_sCurrentElement = "";
                ELEMENTMENU = TEXTUREMENU;
                g_sType = "texture";
                ElementMenu(kID, g_lTextureElements); 
            }            
        }
        else if (sCommand == "settexture")
        {
            if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
            }
            else
            {
                llMessageLinked(LINK_SET, APPEARANCE_TEXTURE, sValue +"§" + sValue2 + "§" + (string)TRUE, kID);
            }
        }                 
    }
}
// pragma inline
HandleAPPEARANCE(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == APPEARANCE_SIZE_FACTOR)
    {
        g_fScaleFactor = (float)sStr;
        if(kID != NULL_KEY)
        {
            SizeMenu(kID);
        }
    }
    else if (iNum == APPEARANCE_ALPHA_SETTINGS)
    {
        g_lAlphaSettings = llParseString2List(llToLower(sStr),[","],[]);
    }
}


/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {
        g_kWearer = llGetOwner();       
        g_fRotNudge = PI / 32.0;//have to do this here since we can't divide in a global var declaration   
        
        BuildElementList();
        
//        Store_StartScaleLoop();
        string sPrefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (sPrefix != "")
        {
            g_sAlphaDBToken = sPrefix + g_sAlphaDBToken;
            g_sColorDBToken = sPrefix + g_sColorDBToken;
            g_sTextureDBToken = sPrefix + g_sTextureDBToken;
        }
        
        loadNoteCards("");                
        
        Debug((string)(llGetFreeMemory() / 1024) + " KB Free");
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
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_RLV_RELAY))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
        else if (iNum >= APPEARANCE_SIZE_FACTOR && iNum <= APPEARANCE_ALPHA)
        {
            HandleAPPEARANCE(iSender,iNum,sStr,kID);
        }
    } 
    
    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kHTTPID)
        {
            if (iStatus == 200)
            {
                //we'll have gotten several lines like "Chartreuse|<0.54118, 0.98431, 0.09020>"
                //parse that into 2-strided list of colorname, colorvector
                g_lColors = llParseString2List(sBody, ["\n", "|"], []);
                g_lColors = llListSort(g_lColors, 2, TRUE);
                ColorMenu(g_kUser);
            }
        }
    }

   dataserver(key query_id, string data)
    {
        if (query_id == g_ktexcardID)
        {
            if (data == EOF)
                loadNoteCards("EOF");
            else
            {
                list temp = llParseString2List(data,[",",":","|","="],[]);
                g_textures += [llList2String(temp,0),llList2Key(temp,1)];
                // bump line number for reporting purposes and in preparation for reading next line
                ++g_noteLine;
                g_ktexcardID = llGetNotecardLine(g_noteName, g_noteLine);
            }
        }
    }
    
   
    changed(integer iChange)
    {
        if(iChange & CHANGED_INVENTORY)
        {
            loadNoteCards("");
        }        
    }
    
}