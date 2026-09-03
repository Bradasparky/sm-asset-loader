#include <sdktools>
#include <json>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 32768

public Plugin myinfo = 
{
	name = "[ANY] Asset Loader",
	author = "Bradasparky",
	description = "Automatically precaches and downloads assets via json config",
	version = "1.0.0",
	url = "https://github.com/Bradasparky/sm-asset-loader"
};

enum
{
    Precache_Model,
    Precache_Sound
}

int g_iTable;
bool g_bLock;
ConVar cvLog;
StringMap g_hExts;

public void OnPluginStart()
{
    g_iTable = FindStringTable("downloadables");
    if (g_iTable == INVALID_STRING_TABLE)
        SetFailState("The 'downloadables' table does not exist.");
    
    g_hExts = new StringMap();
    g_hExts.SetValue("wav", Precache_Sound);
    g_hExts.SetValue("mp3", Precache_Sound);
    g_hExts.SetValue("vmt", Precache_Model);
    g_hExts.SetValue("mdl", Precache_Model);

    cvLog = CreateConVar("sm_assetloader_log", "0", "Toggle precached asset logging.", _, true, 0.0, true, 1.0);
    RegAdminCmd("sm_reload_assets", Command_ParseAssets, ADMFLAG_ROOT, "Reload the asset config.");
}

Action Command_ParseAssets(int iClient, int iArgs)
{
    ParseAssets();
    ReplyToCommand(iClient, "[SM] Parsed assets successfully!");
    return Plugin_Handled;
}

public void OnMapStart()
{
    ParseAssets();   
}

void ParseAssets()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/assetloader.json");
    JSON_Object hJson = json_read_from_file(sPath);
    if (hJson == INVALID_HANDLE)
        SetFailState("Failed to read from %s", sPath);
    
    JSON_Array hAssets[2];
    hAssets[0] = view_as<JSON_Array>(hJson.GetObject("precache"));
    hAssets[1] = view_as<JSON_Array>(hJson.GetObject("download"));

    bool bLog = cvLog.BoolValue;
    for (int bDownload = 0; bDownload < sizeof(hAssets); bDownload++)
    {
        if (hAssets[bDownload] == INVALID_HANDLE)
            continue;
        
        int iLength = hAssets[bDownload].Length;
        if (iLength == 0)
            continue;
        
        if (bLog)
        {
            if (bDownload)
                PrintToServer("Download List:\n + = Precached & Added to Downloads\n - = No Precache Method, Added to Downloads \n ! = Missing\n- - - - - - - - - - - -");
            else
                PrintToServer("Precache List:\n + = Precached\n - = No Precache Method\n ! = Missing\n- - - - - - - - - - - -");
        }

        if (bDownload)
            g_bLock = LockStringTables(false);

        int iPrecache, iExt;
        char sFile[PLATFORM_MAX_PATH];
        for (int i; i < iLength; i++)
        {
            if (hAssets[bDownload].GetType(i) != JSON_Type_String)
                continue;
            
            hAssets[bDownload].GetString(i, sFile, sizeof(sFile));
            if (!FileExists(sFile, true))
            {   
                if (bLog)
                    PrintToServer(" ! %s", sFile);
                continue;
            }
            
            if (bDownload)
                AddToStringTable(g_iTable, sFile);
            
            iExt = StrContains(sFile, ".");
            if (iExt == -1 || !g_hExts.GetValue(sFile[iExt + 1], iPrecache))
            {
                if (bLog)
                    PrintToServer(" - %s", sFile);
                continue;
            }
            
            bool bPrecached = true;
            switch (iPrecache)
            {
                case Precache_Model: PrecacheModel(sFile);
                case Precache_Sound: PrecacheSound(sFile);
                default: bPrecached = false;
            }

            if (bLog)
            {
                if (bPrecached)
                    PrintToServer(" + %s", sFile);
                else
                    PrintToServer(" - %s", sFile);
            }
        }

        if (bDownload)
            LockStringTables(g_bLock);
        else if (bLog)
            PrintToServer(" ");
    }

    hJson.Cleanup();
}
