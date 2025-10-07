-- FPV_Monster.lua怪物第一人称Monster
local FPV = {}

FPV.cfg = {
  log_path = "C:/Windy/log.txt",
  old_cam_name = "MainCamera(Clone)",
  new_cam_name = "MainCamera(Clone)(Clone)",
  monster_model_root = "EntityRoot/MonsterRoot/Monster_Hili_Fire_01(Clone)test/Monster_Hili_Fire_01_Model",
  local_offset = CS.UnityEngine.Vector3(-0.045,0.1,0),
  fov = 68, near_clip = 0.02,
  disable_cinemachine = true, set_main_camera = true, log_verbose = true,
}

-- Head 
local HEAD_PATH = table.concat({
  "Bip001","Bip001 Pelvis","Bip001 Spine","Bip001 Spine1",
  "Bip001 Spine2","Bip001 Neck","Bip001 Head"
}, "/")

FPV.state = { old_cam=nil, new_cam=nil, head_tf=nil }

-- ===== log/工具=====
local function ensure_dir(p)
  local d=p:match("^(.*)/[^/]+$") or p:match("^(.*)\\[^\\]+$"); if d and CS.System and CS.System.IO and CS.System.IO.Directory then CS.System.IO.Directory.CreateDirectory(d) end
end
local function log_raw(path, s) ensure_dir(path); local ok,f=pcall(io.open,path,"a"); if ok and f then f:write(os.date("[%Y-%m-%d %H:%M:%S] ")..tostring(s).."\n"); f:close() end end
local function fmt_v3(v) return string.format("(%.4f, %.4f, %.4f)", v.x,v.y,v.z) end
local function fmt_euler(q) local e=q.eulerAngles; return string.format("(%.3f°, %.3f°, %.3f°)",e.x,e.y,e.z) end
local function dump_tf(cfg, tag, tf)
  if not cfg.log_verbose then return end
  if not tf then log_raw(cfg.log_path, tag.." [Transform=nil]"); return end
  local function pathOf(t) local ps,cur={},t; while cur do table.insert(ps,1,cur.gameObject.name); cur=cur.parent end; return table.concat(ps,"/") end
  log_raw(cfg.log_path, tag.." PATH: "..pathOf(tf))
  log_raw(cfg.log_path, tag.." WORLD pos="..fmt_v3(tf.position).." rot="..fmt_euler(tf.rotation))
  log_raw(cfg.log_path, tag.." LOCAL pos="..fmt_v3(tf.localPosition).." rot="..fmt_euler(tf.localRotation))
end
local function find_by_full_path(absPath)
  local rootName = absPath:match("^[^/]+"); local rest = absPath:sub(#rootName+2)
  local root = CS.UnityEngine.GameObject.Find(rootName); if not root then return nil end
  if not rest or rest=="" then return root end
  local t = root.transform:Find(rest); return t and t.gameObject or nil
end
local function find_child_by_path(go, rel) if not go or rel=="" then return nil end local t=go.transform:Find(rel); return t and t.gameObject or nil end
local function safe_look(f,u)
  if f.sqrMagnitude<1e-8 then f=CS.UnityEngine.Vector3.forward end
  if u.sqrMagnitude<1e-8 then u=CS.UnityEngine.Vector3.up end
  return CS.UnityEngine.Quaternion.LookRotation(f.normalized,u.normalized)
end

-- ===== 主流程
local function run_monster(cfg, st)
  log_raw(cfg.log_path, "==== [MONSTER] start ====")

  local modelRoot = find_by_full_path(cfg.monster_model_root)
  if not modelRoot then log_raw(cfg.log_path, "FAIL: 未找到 Monster 模型根: "..tostring(cfg.monster_model_root)); return false end
  dump_tf(cfg, "MonsterModelRoot", modelRoot.transform)

  -- Old / New Cam
  local oldCam = CS.UnityEngine.GameObject.Find(cfg.old_cam_name)
  if not oldCam then log_raw(cfg.log_path, "FAIL: "..cfg.old_cam_name.." 不存在"); return false end
  st.old_cam = oldCam; dump_tf(cfg, "OldCam", oldCam.transform)
  local newCam = CS.UnityEngine.GameObject.Find(cfg.new_cam_name)
  if not newCam then newCam = CS.UnityEngine.Object.Instantiate(oldCam); newCam.name=cfg.new_cam_name; log_raw(cfg.log_path,"Clone new cam")
  else log_raw(cfg.log_path,"Reuse new cam") end
  st.new_cam = newCam

  local headGO = find_child_by_path(modelRoot, HEAD_PATH); if not headGO then log_raw(cfg.log_path, "FAIL: 未找到 Head: "..HEAD_PATH); return false end
  st.head_tf = headGO.transform; dump_tf(cfg, "Head", st.head_tf)

  newCam.transform:SetParent(st.head_tf, false)
  newCam.transform.localPosition = cfg.local_offset
  local bodyForward = modelRoot.transform.forward
  newCam.transform.rotation = safe_look(bodyForward, CS.UnityEngine.Vector3.up)
  dump_tf(cfg, "NewCam(after parent+pos+rot)", newCam.transform)

  -- 相机参数 & 组件
  local cam = newCam:GetComponent(typeof(CS.UnityEngine.Camera)); if cam then cam.fieldOfView=cfg.fov; cam.nearClipPlane=cfg.near_clip end
  if cfg.disable_cinemachine then local brain=newCam:GetComponent(typeof(CS.Cinemachine.CinemachineBrain)); if brain then brain.enabled=false end end

  -- 主相机切换
  if cfg.set_main_camera then
    local alOld = oldCam:GetComponent(typeof(CS.UnityEngine.AudioListener)); if alOld then alOld.enabled=false end
    oldCam.tag="Untagged"
    local alNew = newCam:GetComponent(typeof(CS.UnityEngine.AudioListener)); if alNew then alNew.enabled=true end
    newCam.tag="MainCamera"; newCam:SetActive(true)
  end

  log_raw(cfg.log_path, "OK: monster first-person")
  return true
end

if not FPV.state._auto then
  FPV.state._auto = true
  pcall(function() run_monster(FPV.cfg, FPV.state) end)
end
return FPV
