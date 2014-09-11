/*--------------------------------------------------------------------------------**
**  File: CDB - appearance ~ core                                                 **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

/*-------------//
//  VARIABLES  //
//-------------*/

integer g_iDebug = FALSE;

key g_kWearer;

// -----  HOVERTEXT --------------
float min_z = 0.25 ; // min height
float max_z = 1.0 ; // max height
vector g_vPrimScale = <0.02,0.02,0.5>; // prim size, initial value (z - text offset height)
vector g_vPrimSlice = <0.490,0.51,0.0>; // prim slice

integer g_iHoverLink=0;
integer g_iHoverLastRank = 0;
integer g_iHoverOn = FALSE;
string g_sHoverText;
vector g_vHoverColor;
string g_sHoverLinkName = "FloatText";
string g_sHoverTextDBToken = "hovertext";
list g_lHoverTextSettings = [];
// --------------------------------

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


integer g_iAppLock = FALSE;
string g_sAppLockToken = "AppLock";

float g_fScaleFactor = 1.00; // the size on rez is always regarded as 100% to preven problem when scaling an item +10% and than - 10 %, which would actuall lead to 99% of the original size
integer g_iSizedByScript = FALSE; // prevent reseting of the script when the item has been chnged by the script
list g_lPrimStartSizes; // area for initial prim sizes (stored on rez)

/*---------------//
//  MESSAGE MAP  //
//---------------*/
integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db
integer HTTPDB_REQUEST_NOCACHE  = 0xCDB205;

integer APPEARANCE_ALPHA        = -0xCDB800;
integer APPEARANCE_COLOR        = -0xCDB801;
integer APPEARANCE_TEXTURE      = -0xCDB802;
integer APPEARANCE_POSITION     = -0xCDB803;
integer APPEARANCE_ROTATION     = -0xCDB804;
integer APPEARANCE_SIZE         = -0xCDB805;
integer APPEARANCE_HOVER        = -0xCDB806;
integer APPEARANCE_ALPHA_SETTINGS = -0xCDB810;
integer APPEARANCE_SIZE_FACTOR  = -0xCDB815;
integer APPEARANCE_HOVER_SETTINGS = -0xCDB816;


/*---------------//
//  FUNCTIONS    //
//---------------*/
Debug (string sStr)
{
    if (g_iDebug){
        llOwnerSay(llGetScriptName() + ": " + sStr);
    }
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) 
{
    if (kID == g_kWearer) 
    {
        llOwnerSay(sMsg);
    } 
    else 
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) 
        {
            llOwnerSay(sMsg);
        }
    }
}


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
        integer iIndex;
        if (!(~(integer)llListFindList(lElement, ["nocolor"])))
        {
            sElement = llToLower(sElement);            
            iIndex = llListFindList(g_lColorElements, [sElement]);
            if (iIndex == -1)
                g_lColorElements += [sElement,(string)n];
            else 
                g_lColorElements = llListReplaceList(g_lColorElements,[sElement,llList2String(g_lColorElements,iIndex+1) + "§" + (string)n ], iIndex, iIndex+1);
        }
        if (!(~(integer)llListFindList(lElement, ["notexture"])))
        {
            sElement = llToLower(sElement);
            iIndex = llListFindList(g_lTextureElements, [sElement]);
            if (iIndex == -1)
                g_lTextureElements += [sElement,(string)n];
            else 
                g_lTextureElements = llListReplaceList(g_lTextureElements,[sElement,llList2String(g_lTextureElements,iIndex+1) + "§" + (string)n ], iIndex, iIndex+1);
        }
        if (!(~(integer)llListFindList(lElement, ["nohide"])))
        {
            sElement = llToLower(sElement);
            iIndex = llListFindList(g_lHideElements, [sElement]);
            if (iIndex == -1)
                g_lHideElements += [sElement,(string)n];
            else 
                g_lHideElements = llListReplaceList(g_lHideElements,[sElement,llList2String(g_lHideElements,iIndex+1) + "§" + (string)n ], iIndex, iIndex+1);
        }
    }
    g_lColorElements = llListSort(g_lColorElements, 2, TRUE);
    g_lTextureElements = llListSort(g_lTextureElements, 2, TRUE);
    g_lHideElements = llListSort(g_lHideElements, 2, TRUE);
    llOwnerSay(llList2CSV(g_lHideElements));
}

string ElementType(integer iLinkNumber)
{
    // return a strided list representing primname|nocolor|notexture|nohide
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
    TextDisplay();   
}

LoadAlphaSettings()
{
    integer n;
    integer iItemCount = llGetListLength(g_lAlphaSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        string sElement = llList2String(g_lAlphaSettings, n);
        float fAlpha = (float)llList2String(g_lAlphaSettings, n + 1);
        SetElementAlpha(sElement, fAlpha, FALSE);
    }
}

SetAllElementsAlpha(float fAlpha, integer bSaveHTTPDB)
{
 //   llSetLinkAlpha(LINK_SET, fAlpha, ALL_SIDES);
    //set alphasettings of all elements to fAlpha (either 1.0 or 0.0 here)
    g_lAlphaSettings = [];
    integer n;
    integer iStop = llGetListLength(g_lHideElements);
    for (n = 0; n < iStop; n=n + 2)
    {
        string sElement = llList2String(g_lHideElements, n);
        SetElementAlpha(sElement, fAlpha, FALSE);
        g_lAlphaSettings += [sElement, fAlpha];
    }
    if (bSaveHTTPDB)
    {
        if (llGetListLength(g_lAlphaSettings)>0)
        {
            llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sAlphaDBToken + "=" + llDumpList2String(g_lAlphaSettings, ","), NULL_KEY);
        }
        else
        {
            llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sAlphaDBToken, NULL_KEY);
        }
    }
}

SetElementAlpha(string sElement2Set, float fAlpha, integer bSaveHTTPDB)
{
    //loop through links, setting color if element type matches what we're changing
    //root prim is 1, so start at 2
    integer iIndex;
    integer i;
    iIndex = llListFindList(g_lHideElements, [sElement2Set]);
    if (iIndex != -1)
    {
        string sElement = llList2String(g_lHideElements,iIndex);
        list lLinks = llParseString2List(llList2String(g_lHideElements,iIndex+1),["§"],[]);
        integer n;
        for (n = 0; n < llGetListLength(lLinks); n++)
        {
            llSetLinkAlpha(llList2Integer(lLinks,n), fAlpha, ALL_SIDES);
        }
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
    if (bSaveHTTPDB)
    {
        if (llGetListLength(g_lAlphaSettings)>0)
        {
            llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sAlphaDBToken + "=" + llDumpList2String(g_lAlphaSettings, ","), NULL_KEY);
        }
        else
        {
            llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sAlphaDBToken, NULL_KEY);
        }
    }
}

LoadColorSettings()
{
    integer n;
    integer iItemCount = llGetListLength(g_lColorSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        string sElement = llList2String(g_lColorSettings, n);
        vector vColor = (vector)llList2String(g_lColorSettings, n + 1);
        SetElementColor(sElement, vColor, FALSE);
    }
}

SetElementColor(string sElement2Set, vector vColor, integer bSaveHTTPDB)
{
    integer iIndex;
    integer i;
    iIndex = llListFindList(g_lColorElements, [sElement2Set]);
    if (iIndex != -1)
    {
        string sElement = llList2String(g_lColorElements,iIndex);
        list lLinks = llParseString2List(llList2String(g_lColorElements,iIndex+1),["§"],[]);
        integer n;
        for (n = 0; n < llGetListLength(lLinks); n++)
        {
            llSetLinkColor(llList2Integer(lLinks,n), vColor, ALL_SIDES);
        }
        //create shorter string from the color vectors before saving
        string sStrColor = (string)vColor;
        //change the g_lColorSettings list entry for the current element
        iIndex = llListFindList(g_lColorSettings, [sElement2Set]);
        if (iIndex != -1)
        {
            g_lColorSettings += [sElement2Set, sStrColor];
        }
        else
        {
            g_lColorSettings = llListReplaceList(g_lColorSettings, [sStrColor], iIndex + 1, iIndex + 1);
        }
    }
    if (bSaveHTTPDB)
    {
        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sColorDBToken + "=" + llDumpList2String(g_lColorSettings, "~"), NULL_KEY);
    }
}

LoadTextureSettings()
{
    integer n;
    integer iItemCount = llGetListLength(g_lTextureSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        string sElement = llList2String(g_lTextureSettings, n);
        key kTex = (key)llList2String(g_lTextureSettings, n + 1);
        SetElementTexture(sElement, kTex, FALSE);
    }
}

SetElementTexture(string sElement2Set, key kTex,integer bSaveHTTPDB)
{
    integer iIndex;
    integer i;
    iIndex = llListFindList(g_lTextureElements, [sElement2Set]);
    if (iIndex != -1)
    {
        string sElement = llList2String(g_lTextureElements,iIndex);
        list lLinks = llParseString2List(llList2String(g_lTextureElements,iIndex+1),["§"],[]);
        integer n;
        for (n = 0; n < llGetListLength(lLinks); n++)
        {
            list lParams=llGetLinkPrimitiveParams(llList2Integer(lLinks,n), [ PRIM_TEXTURE, ALL_SIDES]);
            integer iSides=llGetListLength(lParams);
            integer iSide;
            list lTemp=[];
            for (iSide = 0; iSide < iSides; iSide = iSide + 4)
            {
                lTemp += [PRIM_TEXTURE, iSide/4, kTex] + llList2List(lParams, iSide+1, iSide+3);
            }
            llSetLinkPrimitiveParamsFast(llList2Integer(lLinks,n), lTemp);
        }

        //change the textures list entry for the current element
        iIndex=llListFindList(g_lTextureSettings, [sElement2Set]);
        if (iIndex != -1)
        {
            g_lTextureSettings += [sElement2Set, kTex];
        }
        else
        {
            g_lTextureSettings = llListReplaceList(g_lTextureSettings, [kTex], iIndex + 1, iIndex + 1);
        }
    }
    if (bSaveHTTPDB)
    {
        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sTextureDBToken + "=" + llDumpList2String(g_lTextureSettings, "~"), NULL_KEY);
    }
}

Store_StartScaleLoop()
{
    g_fScaleFactor = 1.00;
    llMessageLinked(LINK_SET, APPEARANCE_SIZE_FACTOR, (string)g_fScaleFactor, NULL_KEY);
}

ScalePrimLoop(float fScale, integer iRezSize, key kAV)
{    
    Debug((string)fScale);
    float resize_scale;

    Notify(kAV, "Scaling started, please wait ...", TRUE);
    g_iSizedByScript = TRUE;

    if (fScale == 1.0)
    {
        resize_scale = 1.0 / g_fScaleFactor;           
    }
    else
    {
        resize_scale = fScale / g_fScaleFactor;
    }

    Debug("Resize | " + (string)fScale + " | " + (string)resize_scale + " | " + (string)g_fScaleFactor);
    
    integer resized;
    
    resized = llScaleByFactor(resize_scale);
    
    if (resized)
    {
        g_fScaleFactor = fScale;
        llMessageLinked(LINK_SET, APPEARANCE_SIZE_FACTOR, (string)g_fScaleFactor, kAV);
        g_iSizedByScript = TRUE;
        Notify(kAV, "Scaling finished, the collar is now on "+ (string)((integer)(g_fScaleFactor * 100)) +"% of the rez size.", TRUE);
    }
    else
    {
        llMessageLinked(LINK_SET, APPEARANCE_SIZE_FACTOR, (string)g_fScaleFactor, kAV);
        Notify(kAV, "Scaling failed, the collar is still at "+ (string)((integer)(g_fScaleFactor * 100)) +"% of the rez size.", TRUE);        
    }

}


ForceUpdate()
{
    //workaround for https://jira.secondlife.com/browse/VWR-1168
    llSetText(".", <1,1,1>, 1.0);
    llSetText("", <1,1,1>, 1.0);
}

AdjustPos(vector vDelta)
{
    if (llGetAttached())
    {
        llSetPos(llGetLocalPos() + vDelta);
        ForceUpdate();
    }
}

AdjustRot(vector vDelta)
{
    if (llGetAttached())
    {
        llSetLocalRot(llGetLocalRot() * llEuler2Rot(vDelta));
        ForceUpdate();
    }
}

// ---  HOVERTEXT  ----

TextDisplay()
{
    if (g_iHoverLink > 1)
    {//don't scale the root prim
        llSetLinkPrimitiveParamsFast(g_iHoverLink, [PRIM_TEXT,g_sHoverText,g_vHoverColor,(float)g_iHoverOn, PRIM_SIZE,g_vPrimScale, PRIM_SLICE,g_vPrimSlice]);    
    }
    else
    {
         llSetLinkPrimitiveParamsFast(g_iHoverLink, [PRIM_TEXT,g_sHoverText,g_vHoverColor,(float)g_iHoverOn]);     
    }
    
    g_lHoverTextSettings = [];
    g_lHoverTextSettings += ["text",g_sHoverText];
    g_lHoverTextSettings += ["on",(string)g_iHoverOn];
    g_lHoverTextSettings += ["height",(string)g_vPrimScale.z];
    g_lHoverTextSettings += ["lastrank",(string)g_iHoverLastRank];
 
    if (llGetListLength(g_lHoverTextSettings)>0)
    {
        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sHoverTextDBToken + "=" + llDumpList2String(g_lHoverTextSettings, "~"), NULL_KEY);
    }
    else
    {
        llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sHoverTextDBToken, NULL_KEY);
    }
}

ShowText(string sNewText)
{

}
//-----------------------------------------

/*---------------//
//  HANDLERS     //
//---------------*/

HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == HTTPDB_RESPONSE)
    {
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);

        if (sToken == g_sAlphaDBToken)
        {
            //we got the list of alphas for each element
            g_lAlphaSettings = llParseString2List(sValue, [","], []);
            LoadAlphaSettings();
        }
        else if (sToken == g_sColorDBToken)
        {
            g_lColorSettings = llParseString2List(sValue, ["~"], []);
            LoadColorSettings();
        }
        else if (sToken == g_sTextureDBToken)
        {
            g_lTextureSettings = llParseString2List(sValue, ["~"], []);
            //llInstantMessage(llGetOwner(), "Loaded texture settings.");
            LoadTextureSettings();
        }
        else if (sToken == g_sHoverTextDBToken)
        {
            g_lHoverTextSettings = llParseString2List(sValue, ["~"], []);
            LoadHoverTextSettings();
        }        
        else if (sToken == g_sAppLockToken)
        {
            g_iAppLock = (integer)sValue;
        }
    }
}



HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llList2String(lParams, 0);
    string sValue = llToLower(llList2String(lParams, 1));
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
    {
        if (sCommand == "text")
        {
            lParams = llDeleteSubList(lParams, 0, 0);//pop off the "text" command
            string sNewText = llDumpList2String(lParams, " ");
            sNewText = llDumpList2String(llParseStringKeepNulls(sNewText, ["\\n"], []), "\n");
            if (g_iHoverOn)
            {
                //only change text if commander has same or greater auth
                if (iNum <= g_iHoverLastRank)
                {
                    if (sNewText == "")
                    {
                        g_sHoverText = "";
                        g_iHoverLastRank = COMMAND_WEARER;
                        g_iHoverOn = FALSE;
                    }
                    else
                    {
                        g_iHoverOn = TRUE;
                        g_sHoverText = sNewText;
                        g_iHoverLastRank = iNum;
                    }
                        TextDisplay();                    
                }
                else
                {
                    Notify(kID,"You currently have not the right to change the float text, someone with a higher rank set it!", FALSE);
                }
            }
            else
            {
                //set text
                if (sNewText == "")
                {
                    g_sHoverText = "";
                    g_iHoverOn = FALSE;
                    g_iHoverLastRank = COMMAND_WEARER;
                }
                else
                {
                    g_sHoverText = sNewText;
                    g_iHoverOn = TRUE;
                    g_iHoverLastRank = iNum;
                }
                TextDisplay();
            }
        }
        else if (sCommand == "textoff")
        {
            if (g_iHoverOn)
            {
                //only turn off if commander auth is >= g_iLastRank
                if (iNum <= g_iHoverLastRank)
                {
                    g_iHoverOn = FALSE;
                    g_iHoverLastRank = COMMAND_WEARER;
                }
            }
            else
            {
                g_iHoverOn = FALSE;
                g_iHoverLastRank = COMMAND_WEARER;
            }
            TextDisplay();
        }
        else if (sCommand == "texton")
        {
            if( g_sHoverText != "")
            {
                g_iHoverLastRank = iNum;
                g_iHoverOn = TRUE;
                TextDisplay();
            }
        }
        else if (sCommand == "textup") 
        {
            g_vPrimScale.z += 0.05 ;
            if(g_vPrimScale.z > max_z) 
            {
                g_vPrimScale.z = max_z ;
            }
            TextDisplay();
        } 
        else if (sCommand == "textdown") 
        {
            g_vPrimScale.z -= 0.05 ;
            if(g_vPrimScale.z < min_z)
            {
                g_vPrimScale.z = min_z ;
            }
            TextDisplay();
        }
        else if (sStr == "reset" && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER))
        {
            g_sHoverText = "";
            TextDisplay();
            llResetScript();
        }
    }    
}

HandleAPPEARANCE(integer iSender, integer iNum, string sStr, key kID)
{
    list lParams = llParseString2List(sStr, ["§"], []);
    string sParam1 = llList2String(lParams, 0);
    string sParam2 = llList2String(lParams, 1);
    string sParam3 = llList2String(lParams, 2);            
    if (iNum == APPEARANCE_POSITION)
    {
        AdjustPos((vector)sParam1);
    }
    else if (iNum == APPEARANCE_ROTATION)
    {
        AdjustRot((vector)sParam1);
    }
    else if (iNum == APPEARANCE_SIZE)
    {
        ScalePrimLoop((float)sParam1, (integer)sParam2, kID);
    }
    else if (iNum == APPEARANCE_ALPHA)
    {
        if (sParam1 == "all")
            SetAllElementsAlpha((float)sParam2, (integer)sParam3);
        else
            SetElementAlpha(sParam1, (float)sParam2, (integer)sParam3);

    }
    else if (iNum == APPEARANCE_COLOR)
    {
        llOwnerSay(sParam1 + "|" + sParam2 + "|" + sParam3);
        SetElementColor(sParam1, (vector)sParam2, (integer)sParam3);        
    }
    else if (iNum == APPEARANCE_TEXTURE)
    {
        SetElementTexture(sParam1, (key)sParam2,(integer)sParam3);         
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
        
        BuildElementList();
        
        g_vHoverColor = (vector)llList2String(llGetLinkPrimitiveParams(g_iHoverLink,[PRIM_COLOR,0]),0);
        
        Store_StartScaleLoop();
        string sPrefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (sPrefix != "")
        {
            g_sAlphaDBToken = sPrefix + g_sAlphaDBToken;
            g_sColorDBToken = sPrefix + g_sColorDBToken;
            g_sTextureDBToken = sPrefix + g_sTextureDBToken;
        }     
        llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);
        llSetTimerEvent(15.0);
        llMessageLinked(LINK_SET,HTTPDB_REQUEST,g_sHoverTextDBToken,NULL_KEY);
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= HTTPDB_SAVE) && (iNum <= HTTPDB_REQUEST_NOCACHE))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        } 
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_EVERYONE))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
        else if (iNum >= APPEARANCE_SIZE_FACTOR && iNum <= APPEARANCE_ALPHA)
        {
            HandleAPPEARANCE(iSender,iNum,sStr,kID);
        }
    } 
    
    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }

        if (iChange & CHANGED_COLOR)
        {
            g_vHoverColor = (vector)llList2String(llGetLinkPrimitiveParams(g_iHoverLink,[PRIM_COLOR,0]),0);
            if (g_iHoverOn)
            {
                TextDisplay();
            }
        }
        
        if (iChange & (CHANGED_SCALE))
        {
            if (!g_iSizedByScript)
            {
                    Store_StartScaleLoop();
            }
        }
        if (iChange & (CHANGED_SHAPE | CHANGED_LINK))
        {
            Store_StartScaleLoop();
        }
    }

    on_rez(integer start)
    {
        llMessageLinked(LINK_SET,HTTPDB_REQUEST,g_sHoverTextDBToken,NULL_KEY);
    }

    run_time_permissions(integer nParam)
    {
        if( nParam & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls( CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT, TRUE, TRUE);
        }
    }
    
    timer()
    {
        if(llGetPermissions() & PERMISSION_TAKE_CONTROLS) return;
        llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);

        // the timer is needed as the changed_size even is triggered twice        
        if (g_iSizedByScript)
            g_iSizedByScript = FALSE;
    }    
}