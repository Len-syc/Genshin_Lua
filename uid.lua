local function CreatePlane()
	local PrimObject = CS.UnityEngine.GameObject.CreatePrimitive(CS.UnityEngine.PrimitiveType.Plane)
	PrimObject.name = "Baka"
	--PrimObject.transform.position = CS.UnityEngine.Vector3(-0.05,-0.05,-0.75)
	--PrimObject.transform.localScale = CS.UnityEngine.Vector3(-0.05,-0.05,-0.05)
	PrimObject:GetComponent(typeof(CS.UnityEngine.MeshRenderer)).material.color = CS.UnityEngine.Color(0.3, 0.6, 0.9, 0.5)
	PrimObject.layer = 8;
	uidobj = CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID"):GetComponent("Text");
	uid = uidobj.text;
	uid = uid:gsub("UID:", "<text>")
	--<size=**>设置字体大小</size>
	--<color=#*****>给字体上色~</color>
	--<b>字体加粗</b>
	--<i>字体倾斜</i>
	uidobj.text = "<i><color=#000000>"..uid.."</color></i>"
	if CS.UnityEngine.GameObject.Find("/Baka") then
		local bakaobj = CS.UnityEngine.GameObject.Find("/Baka")
		CS.MoleMole.ActorUtils.ShowMessage(bakaobj.transform.position.y)
	end
	CS.MoleMole.ActorUtils.SetAvatarPos({x = 0, y = 1007, z = 0})
end

local function onError(error)
    CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID"):GetComponent("Text").text = tostring(error)
	CS.MoleMole.ActorUtils.ShowMessage(tostring(error))
end

xpcall(CreatePlane, onError)
