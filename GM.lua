-- 日志打印
function logDebug(msg)
    -- CS.MoleMole.ActorUtils.ShowMessage(msg)
end

function logInfo(msg)
    CS.MoleMole.ActorUtils.ShowMessage(msg)
end

-- 异常回调
function onError(error)
    logDebug(error)
end

local function findActiveAvatar()
    local avatarRoot = CS.UnityEngine.GameObject.Find("/EntityRoot/AvatarRoot")
    if avatarRoot.transform.childCount == 0 then
        return
    end
    for i = 0, avatarRoot.transform.childCount - 1 do
        local avatar = avatarRoot.transform:GetChild(i)
        if avatar.gameObject.activeInHierarchy then
            return avatar.gameObject
        end
    end
end

-- 克隆角色
local function cloneCharacter()
    local function clone()
        local avatar = findActiveAvatar()
        if avatar == nil then
            return
        end
        local position = avatar.transform.position
        local rotation = avatar.transform.rotation
        local offsetDummy = CS.UnityEngine.GameObject.Find("OffsetDummy")
        local child = offsetDummy.transform:GetChild(0)
        local animator = child:GetComponent("Animator")
        animator.enabled = false
        local newAvatar = CS.UnityEngine.GameObject.Instantiate(child)
        newAvatar.transform.position = position
        newAvatar.transform.rotation = rotation
        animator.enabled = true
    end

    local function onError(error)
        logDebug(tostring(error))
    end

    xpcall(clone, onError)
end

-- 创建功能按钮
function createFuncBtn(name, text, func, pos)
    local obj = CS.UnityEngine.GameObject(name)
    -- 空白背景图
    obj:AddComponent(typeof(CS.UnityEngine.UI.Image))
    -- 按钮
    local btn = obj:AddComponent(typeof(CS.UnityEngine.UI.Button))
    btn.onClick:AddListener(func)
    -- 复制一个uid框拿来用
    local txt = CS.UnityEngine.GameObject.Instantiate(CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID"))
    txt:GetComponent("Text").text = "<color=#000><size=16>" .. text .. "</size></color>"
    txt.transform:SetParent(obj.transform)
    txt.transform.localScale = CS.UnityEngine.Vector3(1.5, 3, 0)
    txt.transform.localPosition = CS.UnityEngine.Vector3(50, -30, 0)
    -- 画布位置
    local canvas = CS.UnityEngine.GameObject.Find("/Canvas")
    obj.transform:SetParent(canvas.transform)
    obj.transform.localScale = CS.UnityEngine.Vector3(1, 0.5, 0)
    obj.transform.localPosition = pos
    obj:SetActive(false)
    return obj
end

gmMenuFlag = false
accSwitchValue = 0.5
fpsSwitchValue = 10
fogSwitchFlag = false
testModeFlag = false
f_Enabled = true
CharcharValue_x = 1
CharcharValue_y = 1
CharcharValue_z = 1

function initGmMenu()
    logDebug("initGmMenu")
    -- 开启live版本客户端的GM按钮
    local btnGm = CS.UnityEngine.GameObject.Find("/Canvas/Pages/InLevelMainPage/GrpMainPage/GrpMainBtn/GrpMainToggle/GrpTopPanel/BtnGm")
    CS.UnityEngine.Object.DontDestroyOnLoad(btnGm)
    CS.UnityEngine.Object.DontDestroyOnLoad(canvas)
    btnGm:SetActive(true)
    canvas:SetActive(true)
    -- 切换加速
    local accSwitch = createFuncBtn("accSwitch",
            "切换加速",
            function()
                CS.UnityEngine.Time.timeScale = accSwitchValue
                logInfo("当前加速倍率: " .. accSwitchValue)
                accSwitchValue = accSwitchValue + 0.5
                if accSwitchValue >= 10.0 then
                    accSwitchValue = 0.5
                end
            end,
            CS.UnityEngine.Vector3(-400, 200, 0))
    -- 切换帧率
    local fpsSwitch = createFuncBtn("fpsSwitch",
            "切换帧率",
            function()
                CS.UnityEngine.Application.targetFrameRate = fpsSwitchValue
                logInfo("当前帧率: " .. fpsSwitchValue)
                fpsSwitchValue = fpsSwitchValue + 10
                if fpsSwitchValue >= 200 then
                    fpsSwitchValue = 10
                end
            end,
            CS.UnityEngine.Vector3(-200, 200, 0))
    -- 迷雾开关 
    local fogSwitch = createFuncBtn("fogSwitch",
            "迷雾开关",
            function()
                if fogSwitchFlag then
                    CS.UnityEngine.RenderSettings.fog = true
                    fogSwitchFlag = false
                else
                    CS.UnityEngine.RenderSettings.fog = false
                    fogSwitchFlag = true
                end
                logInfo("迷雾开启: " .. tostring(CS.UnityEngine.RenderSettings.fog))
            end,
            CS.UnityEngine.Vector3(0, 200, 0))
    -- 克隆角色按钮
    local cloneButton = createFuncBtn("cloneButton",
            "克隆角色",
            cloneCharacter,
            CS.UnityEngine.Vector3(200, 200, 0))

    -- PosReset按钮
    local posResetButton = createFuncBtn("posResetButton",
            "PosReset",
            function()
                CS.MoleMole.ActorUtils.SetAvatarPos({x = 2765.462646484375, y = 195.1754150390625, z = -1742.79443359375})
                --
                CS.MoleMole.ActorUtils.ShowMessage("ok")
            end,
            CS.UnityEngine.Vector3(400, 200, 0))
    posResetButton:SetActive(false)
    -- -- UI开关按钮
    -- local uiSwitch = createFuncBtn("uiSwitch",
    --         "ShowUI",
    --         function()
    --             local uiCamera = CS.UnityEngine.GameObject.Find("/UICamera")
    --             if uiCamera then
    --                 if f_Enabled then
    --                     uiCamera:SetActive(false)
    --                 -- else
    --                 --     uiCamera:SetActive(true)
    --                 end
    --             end
    --         end,
    --         CS.UnityEngine.Vector3(-400, -20, 0))
    -- 角色大小按钮
    local celestia1 = createFuncBtn("copy_scene",
            "test1",
            function()
                -- local OldCelestia = CS.UnityEngine.GameObject.Find("/StageRoot/CharacterSelectSceneNew(Clone)")--dev
                local OldCelestia = CS.UnityEngine.GameObject.Find("/UISceneRoot/CharacterSelectSceneNew(Clone)")--live
                -- local tianli = CS.UnityEngine.GameObject.Find("/StageRoot/CharacterSelectSceneNew(Clone)/Avatars")--dev
                local tianli = CS.UnityEngine.GameObject.Find("/UISceneRoot/CharacterSelectSceneNew(Clone)/Avatars")--live
                if OldCelestia then
                    CS.MoleMole.ActorUtils.ShowMessage("Found") -- 调试信息
                    OldCelestia:SetActive(false)
                    tianli:SetActive(false)
                    Celestia = CS.UnityEngine.Object.Instantiate(OldCelestia)
                    New_tianli = CS.UnityEngine.Object.Instantiate(tianli)
                    New_tianli.transform.name = "tianli"
                    Celestia.transform.name = "Celestia"
                    Celestia:SetActive(false)
                    New_tianli:SetActive(false)
                    tianli:SetActive(true)
                    OldCelestia:SetActive(true)
                    CS.UnityEngine.Object.DontDestroyOnLoad(Celestia)
                    CS.UnityEngine.Object.DontDestroyOnLoad(New_tianli)
                else
                    CS.MoleMole.ActorUtils.ShowMessage("not found") -- 调试信息
                end
            end,
            CS.UnityEngine.Vector3(-400, 100, 0))
    local celestia2 = createFuncBtn("load_scene","test2",
            function()
                local BigWorld = CS.UnityEngine.GameObject.Find("/BigWorld(Clone)")
                if BigWorld and Celestia then
                    Celestia:SetActive(true)--1
                    New_tianli:SetActive(true)--1
                    CS.MoleMole.ActorUtils.ShowMessage("ok") -- 调试信息
                    -- CS.UnityEngine.Object.Destroy(CS.UnityEngine.GameObject.Find("/Celestia/ModelCamera"))
                    CS.UnityEngine.Object.Destroy(CS.UnityEngine.GameObject.Find("/Celestia/Cam"))
                    local StartPos = CS.MoleMole.ActorUtils.GetAvatarPos()
                    -- local Player_NewPos = CS.UnityEngine.Vector3(2704.109, 2069.975, -1560.202)
                    -- CS.MoleMole.ActorUtils.SetAvatarPos(Player_NewPos)
                    -- BigWorld:SetActive(false)
                    -- local cord = CS.UnityEngine.Vector3(-22.1819,1000.7352,12.1539)
                    -- dev pos 2718.5146484375,2000.0,-1679.607666015625
                    -- live pos -22.1819,194.7352,12.1539
                    Celestia:SetActive(false)
                    Celestia.transform.position=CS.UnityEngine.Vector3(StartPos.x,1300.7352,StartPos.z)
                    Celestia:SetActive(true)
                    New_tianli:SetActive(false)
                    New_tianli.transform.position=CS.UnityEngine.Vector3(StartPos.x, 1300, StartPos.z)
                    New_tianli:SetActive(true)
                    local pos_player = CS.UnityEngine.GameObject.Find("/EntityRoot/AvatarRoot")
                    pos_player:SetActive(false)
                    pos_player.transform.position=CS.UnityEngine.Vector3(StartPos.x, 1500, StartPos.z)
                    pos_player:SetActive(true)
                else
                    CS.MoleMole.ActorUtils.ShowMessage("not found")
                end
            end,
            CS.UnityEngine.Vector3(-200, 100, 0))
    -- 注册GM按钮回调
    local button = btnGm:GetComponent(typeof(CS.UnityEngine.UI.Button))
    CS.UnityEngine.Object.DontDestroyOnLoad(button)
    local function showGmMenu()
        accSwitch:SetActive(true)
        fogSwitch:SetActive(true)
        fpsSwitch:SetActive(true)
        cloneButton:SetActive(true)
        posResetButton:SetActive(true)
        celestia1:SetActive(true)
        celestia2:SetActive(true)
        
    end
    local function hideGmMenu()
        accSwitch:SetActive(false)
        fogSwitch:SetActive(false)
        fpsSwitch:SetActive(false)
        cloneButton:SetActive(false)
        posResetButton:SetActive(false)
        celestia1:SetActive(false)
        celestia2:SetActive(false)
    end
    button.onClick:AddListener(
            function()
                showGmMenu()
                if gmMenuFlag then
                    hideGmMenu()
                    gmMenuFlag = false
                else
                    showGmMenu()
                    gmMenuFlag = true
                end
            end)
    logDebug("initGmMenu ok")
end

xpcall(initGmMenu, onError)
