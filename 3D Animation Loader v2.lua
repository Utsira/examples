--# Main
--3D Animation viewer
displayMode(OVERLAY)

local walkSpeed, joyMax = -1.9, 120

function setup() 
    aerial=color(28, 33, 36, 255)
    fill(0, 255, 58, 255)
    stroke(0, 255, 58, 128)
    strokeWidth(10)
    floor.init()
    linearShader=shader(FrameBlendNoTex.linearVert, FrameBlendNoTex.frag)
    splineShader=shader(FrameBlendNoTex.splineVert, FrameBlendNoTex.frag)

    parameter.watch("FPS")
    parameter.action("DeleteStoredData",DeleteData)

    FPS=0
    cam={} --move camera around
    cam.p=vec4(70,250,150,1)
    tween(13,cam.p,{x=-50}, {easing=tween.easing.sineInOut, loop=tween.loop.pingpong})
    tween(19,cam.p,{y=80}, {easing=tween.easing.sineInOut, loop=tween.loop.pingpong})
    tween(27,cam.p,{z=10}, {easing=tween.easing.sineInOut, loop=tween.loop.pingpong})

    walkAngle, angleTarget=0,0
    LoadModel()
end

function LoadModel() 
    model=Rig(Models[1].name,Models[1].mtl,Models[1].actions)
    oldDraw=draw
    draw=loadDraw
end

function DeleteData()
    if model then model:DeleteData() end
end

function loadDraw()
    local _,c,total = coroutine.resume(model.loader)
    background(aerial)
    local unit = WIDTH/(total+3)
    rect(100,400,c*unit,50)
    if model.ready then
        draw=oldDraw
        displayMode(FULLSCREEN)
        print("ready")
    end
end

function draw()
    background(aerial) 
    FPS=FPS*0.9+0.1/DeltaTime

    perspective(65)
    camera(cam.p.x,cam.p.y,cam.p.z, 0,0,80, 0,0,1)
    pushMatrix()
 
    floor.draw(cam.p)
    
    rotate(walkAngle,0,0,1)
    walkVec=vecMat(vec2(0,walkSpeed), modelMatrix()) --get the movement vector from angle of transform
    
    model:anim()
    model:draw(cam.p)
    
    popMatrix()
    ortho()
    -- Restore the view matrix to the identity   
    viewMatrix(matrix())
    if walking then 
        local diff = (((angleTarget - walkAngle)+180)%360)-180
        walkAngle = walkAngle + diff * 0.1 --turn toward target angle
        floor.move(walkVec) --move floor in opposite direction to walking
        fill(127, 127, 127, 130) --draw joypad ellipses
        stroke(127, 127, 127, 70)
        strokeWidth(10)
        ellipse(touch.x,touch.y, 100)
        noFill()
        ellipse(anchor.x,anchor.y,joyMax*2+100)
    end  
end

function touched(t)
    if t.state==ENDED then 
        if walking then
            model:endAnim() --animate to stand-still
            walking=false
        end
    elseif t.state==BEGAN then 
        if t.x<WIDTH*0.5 then
            model:cueAnim("walk", {0,1,2,3,4}) --anim name matches key identifier in assets tab
            walking=true
            anchor=vec2(t.x,t.y)
        else
            walking=false
            model:cueAnim("kick", {0,1,2,3,2,1,0,0}, 0.1)
        end
    elseif t.state==MOVING and walking then
        touch=vec2(t.x, t.y)
        local diff = touch-anchor
        if diff:len()>joyMax then --constrain joystick
            touch = anchor + diff:normalize() * joyMax
        end
        angleTarget=math.deg(math.atan(diff.y,diff.x))+90 --not 100% sure why we need to add 90deg
    end
end

function vecMat(vec, mat) --rotate vector by current transform. 
    return vec2(mat[1]*vec.x + mat[5]*vec.y, mat[2]*vec.x + mat[6]*vec.y)
end

--# Assets
--Assets
Models={

    {name="captainCodea",
    mtl="https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaStand.mtl",
    actions={
        default={
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaStand.obj",
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaStand2.obj",},
        walk={ --these key identifiers used to cue up anim
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaWalk_000000.obj",
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaWalk_000005.obj",
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaWalk_000010.obj",
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaWalk_000015.obj"},
        kick={
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaKick_000003.obj",
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaKick_000005.obj",
        "https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodeaKick_000008.obj",},
    }},

}
--# OBJ
--OBJ library

OBJ=class()
OBJ.DataPrefix="cfg_"
OBJ.imgPrefix="Documents:z3D"
OBJ.modelPrefix="mesh_"

function OBJ:init(name,url,material)    
    self.name=name
    self.mtl=material
    self.data=readGlobalData(OBJ.DataPrefix..name)
    if self.data then
        self.state="hasData"
    else
        http.request(url,function(d) self:DownloadData(d) end)
    end  
end

function OBJ:DownloadData(data)    
    if data~=nil and (string.find(data,"OBJ File") or string.find(data,"ply") ) then
        saveGlobalData(OBJ.DataPrefix..self.name,data)
        self.data=data
        self.state="hasData" --can't process it until we have the mtl file
    else print("Error loading data for "..self.name..i) return end
end

function OBJ:ProcessData()
    print ("processing"..self.name)
    local p, v, tx, t, np, n, c={},{},{},{},{},{},{} --new: c for vertex colors (set by material)
    --data section
    local s=self.data
    local mtl=self.mtl.mtl
    local mname

    for line in s:gmatch("[^\r\n]+") do

    local code=string.sub(line,1,2)
    if string.find(line,"usemtl") then mname=OBJ.GetValue(line) end --new: keep each material on same mesh
    
    if code=="v " then --point position
        p[#p+1]=OBJ.GetVec3(line)
    elseif code=="vn" then --point normal
        np[#np+1]=OBJ.GetVec3(line)
    elseif code=="vt" then --texture co-ord
        tx[#tx+1]=OBJ.GetVec2(line)
    elseif code=="f " then --vertex
        local pts,ptex,pnorm=OBJ.GetList(line)
        if #pts==3 then
            for i=1,3 do
                v[#v+1]=p[tonumber(pts[i])]
                if mname then c[#c+1]=mtl[mname].Kd end --new: set vertex color according to diffuse component of current material
            end
            if ptex then for i=1,3 do t[#t+1]=tx[tonumber(ptex[i])] end end
            if pnorm then for i=1,3 do n[#n+1]=np[tonumber(pnorm[i])] end end
        else
            alert("add a triangulate modifier to the mesh and re-export", "non-triangular face detected") --new: insist on triangular faces
            return            
        end
    end
    end
    
     if #n==0 then n=CalculateAverageNormals(v) end
    self.v = v
    self.t = t
    self.c = c 
    self.n = n
--    self.mesh = {v=v, t=t, c=c, n=n}
    print (self.name..": "..#v.." vertices processed")
    self.data=nil
    self.state = "processed"
   -- print("processed")
end

function OBJ:DeleteData()
    saveGlobalData(OBJ.DataPrefix..self.name,nil)
end

function OBJ.GetColor(s)
  local s1=string.find(s," ")
  local s2=string.find(s," ",s1+1)
  local s3=string.find(s," ",s2+1)
  return color(string.sub(s,s1+1,s2-1)*255,string.sub(s,s2+1,s3-1)*255,string.sub(s,s3+1,string.len(s))*255)
end

function OBJ.GetVec3(s)
  local s1=string.find(s," ")
  local s2=string.find(s," ",s1+1)
  local s3=string.find(s," ",s2+1)
  return vec3(math.floor(string.sub(s,s1+1,s2-1)*100)/100,
    math.floor(string.sub(s,s2+1,s3-1)*100)/100,
    math.floor(string.sub(s,s3+1,string.len(s))*100)/100)
end

function OBJ.GetVec2(s)
  local s1=string.find(s," ")
  local s2=string.find(s," ",s1+1)
  local s3=string.find(s," ",s2+1)
  if s3 then
      return vec3(math.floor(string.sub(s,s1+1,s2-1)*100)/100,
            math.floor(string.sub(s,s2+1,s3-1)*100)/100)
  else
      return vec2(math.floor(string.sub(s,s1+1,s2-1)*100)/100,
            math.floor(string.sub(s,s2+1,string.len(s))*100)/100)
  end
end

function OBJ.GetValue(s)
  return string.sub(s,string.find(s," ")+1,string.len(s))
 end
 
function OBJ.trim(s)
  while string.find(s,"  ") do s = string.gsub(s,"  "," ") end
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function OBJ.split(s,sep)
  sep=sep or "/"
  local p={}
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(s,pattern, function(c) p[#p+1] = c end)
  return p
end

function OBJ.GetList(s)
   local p,t,n={},{},{}
   --for word in s:gmatch("%w+") do table.insert(p, word) end
   p=OBJ.split(s," ")
   table.remove(p,1)
   for i=1,#p do
      local a=OBJ.split(p[i])
      if #a==1 then
        p[i]=math.abs(a[1])
      elseif #a==2 then
        p[i]=math.abs(a[1])
        t[i]=math.abs(a[2])
      elseif #a==3 then
        p[i]=math.abs(a[1])
        t[i]=math.abs(a[2])
        n[i]=math.abs(a[3])
      end
   end
   return p,t,n
end

function CalculateNormals(vertices)
    --this assumes flat surfaces, and hard edges between triangles
    local norm = {}
    for i=1, #vertices,3 do --calculate normal for each set of 3 vertices
        local n = ((vertices[i+1] - vertices[i]):cross(vertices[i+2] - vertices[i])):normalize()
        norm[i] = n --then apply it to all 3
        norm[i+1] = n
        norm[i+2] = n
    end
    return norm
end   

function CalculateAverageNormals(vertices)
    --average normals at each vertex
    --first get a list of unique vertices, concatenate the x,y,z values as a key
    local norm,unique= {},{}
    for i=1, #vertices do
        unique[vertices[i].x ..vertices[i].y..vertices[i].z]=vec3(0,0,0)
    end
    --calculate normals, add them up for each vertex and keep count
    for i=1, #vertices,3 do --calculate normal for each set of 3 vertices
        local n = (vertices[i+1] - vertices[i]):cross(vertices[i+2] - vertices[i]) 
        for j=0,2 do
            local v=vertices[i+j].x ..vertices[i+j].y..vertices[i+j].z
            unique[v]=unique[v]+n  
        end
    end
    --calculate average for each unique vertex
    for i=1,#unique do
        unique[i] = unique[i]:normalize()
    end
    --now apply averages to list of vertices
    for i=1, #vertices,3 do --calculate average
        local n = (vertices[i+1] - vertices[i]):cross(vertices[i+2] - vertices[i]) 
        for j=0,2 do
            norm[i+j] = unique[vertices[i+j].x ..vertices[i+j].y..vertices[i+j].z]
        end
    end
    return norm 
end      

--# MTL
MTL = class(OBJ)

function MTL:init(name,url) 
    self.name=name
    self.data=readGlobalData(OBJ.DataPrefix..name)
    if self.data then
        self:ProcessData()
    else
        http.request(url,function(d) self:DownloadData(d) end)
    end
end

function MTL:DownloadData(data)  
    sound(SOUND_JUMP, 16452)
    if data~=nil and string.find(data,"MTL File") then
        saveGlobalData(OBJ.DataPrefix..self.name,data)
        self.data=data
        self:ProcessData()
    else print("Error loading data for "..self.name..i) return end
end

function MTL:ProcessData()
    self.mtl={}
    
    local s=self.data
    local mname

    for line in s:gmatch("[^\r\n]+") do
        line=OBJ.trim(line)
     
        --material definition section

        if string.find(line,"newmtl") then
            mname=OBJ.GetValue(line)
            --print(mname)
            self.mtl[mname]={}
        else
            local code=string.sub(line,1,2)
            if code=="Ka" then --ambient
                self.mtl[mname].Ka=OBJ.GetColor(line)
                --print(mname,"Ka",OBJ.mtl[mname].Ka[1],OBJ.mtl[mname].Ka[2],OBJ.mtl[mname].Ka[3])
            elseif code=="Kd" then --diffuse
                self.mtl[mname].Kd=OBJ.GetColor(line)
                --print(mname,"Kd",OBJ.mtl[mname].Kd[1],OBJ.mtl[mname].Kd[2],OBJ.mtl[mname].Kd[3])
            elseif code=="Ks" then --specular
                self.mtl[mname].Ks=OBJ.GetColor(line)
                --print(mname,"Ks",OBJ.mtl[mname].Ks[1],OBJ.mtl[mname].Ks[2],OBJ.mtl[mname].Ks[3])
            elseif code=="Ns" then --specular exponent
                self.mtl[mname].Ns=OBJ.GetValue(line)
                --print(mname,"Ns",OBJ.mtl[mname].Ns)
            elseif code=="ill" then --illumination code
                self.mtl[mname].illum=OBJ.GetValue(line)
                --print(mname,"illum",OBJ.mtl[mname].illum)
            elseif code=="ma" then --texture map name. New: only 1 texture per model
                local u=OBJ.split(OBJ.GetValue(line)," ")
                if string.find(u[1],"%.") then
                    self.map=string.sub(u[1],1,string.find(u[1],"%.")-1) --self.mtl[mname]
                else
                    self.map=u[1]
                end
                self.path=u[2]
                --print(mname,line,"\n",OBJ.mtl[mname].map,"\n",OBJ.mtl[mname].path)
            end
        end
    end
    self.state="processed"
    print ("material processed")
        --download images if not stored locally
   -- self.MissingImages={}
   -- for i,O in pairs(self.mtl) do
        if self.map then
            local y=readImage(OBJ.imgPrefix..self.map)
            if not y then 
              --  self:LoadImages() 
                LoadImages(self.path, OBJ.imgPrefix..self.map, function() self.ready=true end)
            else
                self.ready=true
            end
            --self.MissingImages[#self.MissingImages+1]={O.map,O.path} end
        else
            self.ready=true
        end
 --   end
   -- if #self.MissingImages>0 then self:LoadImages() 
   -- else self.ready=true end
end

function MTL:DeleteData()
    if self.map then saveImage(OBJ.imgPrefix..self.map,nil) end
    --[[
    for i,O in pairs(self.mtl) do
        if O.map then
            ---print("deleting "..OBJ.imgPrefix..O.map)
            local y=saveImage(OBJ.imgPrefix..O.map,nil)
        end
    end
      ]]
end

function MTL:LoadImages()
    --print("downloading"..self.MissingImages[1][1])
    http.request(self.path,function(d) self:StoreImage(d) end) --self.MissingImages[1][2]
end

function MTL:StoreImage(d)
    --print("saving"..self.MissingImages[1][1])
    saveImage(OBJ.imgPrefix..self.map,d) --self.MissingImages[1][1]
  --  table.remove(self.MissingImages,1)
   -- if #self.MissingImages==0 then self.ready=true else self:LoadImages() end
    self.ready=true
end

function LoadImages(path, name, callback)
    --print("downloading"..self.MissingImages[1][1])
    http.request(path, function(d) StoreImage(d, name, callback) end) --self.MissingImages[1][2]
end

function StoreImage(d, name, callback)
    --print("saving"..self.MissingImages[1][1])
    saveImage(name,d) --self.MissingImages[1][1]
  --  table.remove(self.MissingImages,1)
   -- if #self.MissingImages==0 then self.ready=true else self:LoadImages() end
    callback()
end

function GetColor(n)
    local b=math.fmod(n,256)
    local a=(n-b)/255
    return color(a,b,0)
end
--# Rig
Rig = class() --load and concatenate all the obj and mtl files into a single mesh, and animate it

function Rig:init(name, mtl, actions)
    self.mtl = MTL(name.."mtl", mtl)  --the mtl material file
    self.obj = {}
    local total = 1
    for action,urls in pairs(actions) do
        self.obj[action]={}
        for i=1,#urls do
            self.obj[action][i]=OBJ(name..action..i, urls[i], self.mtl) --the obj files (nb pass them the material file)
            total = total + 1
        end
        print (#urls.." frames: "..action)
    end
    self.frames={0}
    
    self.loader=coroutine.create(function()
        local c=1
        local finished=false
        while not finished do
            local loaded = true
            for _,action in pairs(self.obj) do
                for i,v in ipairs(action) do
                    if self.mtl.state=="processed" and v.state=="hasData" then --if mtl file has processed and obj file loaded, then ...
                        v:ProcessData() --can start processing obj files
                    end
                    if v.state=="processed" then
                        c = c + 1
                    else
                        loaded=false
                    end
                    coroutine.yield(c, total)
                end
            end
            if self.mtl.ready and loaded then --if all files have processed and images have loaded then can build mesh
                self:BuildMesh()
                c = c + 1
                finished=true
                
            end
        end
        coroutine.yield(c, total)
    end)
end

function Rig:draw(e)
    self.mesh.shader.modelMatrix=modelMatrix() --part of lighting
    self.mesh.shader.eye=e
    self.mesh:draw()
end

local sixtieth = 1/60

function Rig:cueAnim(actionId, frames, speed)
    local action = self.obj[actionId]
    
    self.frames = frames
    self.speed = speed or 0.05
    self.frame = 0
    
    if self.frames[1]==0 then --tween strips away leading 0 after second frame is reached
        tween.delay(sixtieth/self.speed, function() 
            table.remove(self.frames, 1)
            self.frame = self.frame - 1 
        end)
    end

    --add frames   
    local m = self.mesh 
    local pos={m:buffer("position1"), m:buffer("position2"), m:buffer("position3"), m:buffer("position4"), m:buffer("position5")}
    local norm = {m:buffer("normal1"), m:buffer("normal2"), m:buffer("normal3"), m:buffer("normal4"), m:buffer("normal5")}

    for i=1, #action do
        local frame=action[i]
        
        for j=1,#frame.v do
           local v = frame.v[j]
            pos[i][j]=vec3(v.x,v.y,v.z) --nb must make an independent copy of the vector
            local n = frame.n[j]
            norm[i][j]=vec3(n.x,n.y,n.z)
        end

    end
end

function Rig:endAnim()
    local start, frac = math.modf(self.frame)
    local current = self.frames[start+1]
    local n = start+2
    if n>#self.frames then n=1 end
    local next = self.frames[n]
    self.frames={current,current,next,0,0}
    self.frame=1+frac
end

function Rig:anim(offset)
    if #self.frames==1 then return end
    local len=#self.frames
    self.frame = self.frame + self.speed
    if self.frame >= len then
        self.frame = self.frame - len
    end
    local offset = offset or 0
    local start, frac = math.modf(self.frame +offset) --find the start frame (indexed to 0 for modulation) and the frameBlend fraction  
    
    self.mesh.shader.frameBlend = frac --set frame interpolation fraction

    local fr={}
    for i=0, 3, 1 do --walk through 4 frames needed fir catmull-rom spline: (0=start-1, 1=start frame, 2=start+1, 3=start+2)
        local j = (start + (i - 1))%len --work out where in self.frames to point, use mod to wrap, index 0 because of mod
        local v = self.frames[j+1] 
        fr[i+1]= v
    end    
    
    if start == len-2 and self.frames[len]==0 and self.frames[len-1]==0 then
        self.frames={0} --if last 2 frames are 0
        self.frame=0     --bring animation to a halt
    end
    
    self.mesh.shader.frames={fr[1],fr[2],fr[3],fr[4]} --pass frame pointers to shader
end

function Rig:BuildMesh() --concatenate files into mesh
    print("buildingMesh")
    local m=mesh()
    local mtl=self.mtl
    local obj=self.obj.default[1] --first obj file is the master
    obj.state="building" --prevent repeat build calls in case load is still running
     print (#obj.v.." vertices")
    m.vertices=obj.v
   
    if #obj.t>0 then m.texCoords=obj.t end
    if #obj.n>0 then m.normals=obj.n end
    if #obj.c>0 then m.colors=obj.c end -- new: set vertex colors
    
    m.shader=splineShader -- linearShader 
    local l=vec3(-100,800,400):normalize()  
    m.shader.light=vec4(l.x,l.y,l.z,0)
    m.shader.lightColor = color(234, 232, 223, 255)
    
    m.shader.ambient=0.3
    if mtl.map then
        local tex=OBJ.imgPrefix..mtl.map
        print("texture:"..tex)
        m.texture=tex
    end
    
    self.mesh=m
    -- self.obj, self.mtl=nil,nil --delete files
    --collectgarbage()  
    self.ready = true
end

function Rig:DeleteData()
    for key,action in pairs(self.obj) do
        for i,v in ipairs(action) do
            v:DeleteData()
        end
    end
    self.mtl:DeleteData()
end

--# Floor
floor={}

local w,h = 256, 256 --512, 512    
local tw, th = 3000,3000

function floor.init()
    floor.m=mesh()
    floor.m.shader=shader(TilerShader.vs, TilerShader.fs)
    floor.m.shader.aerial=aerial

    local name="Documents:lichen brick2"
    local img=readImage(name)
    if not img then
        LoadImages("http://homeinteriorsdesigns.info/wp-content/uploads/2014/09/seamless-stone-texture.jpg", name, function() floor.m.texture=readImage(name) floor.ready=true end)
    else
        floor.m.texture=img
        floor.ready=true
    end   

    floor.m.shader.fogRadius = tw*0.3
    floor.m:addRect(0,0,tw,th)

    local a,b,c,d = vec2(-w/tw, h/th), vec2(-w/tw,-h/th), vec2(w/tw, -h/th), vec2(w/tw, h/th)
    floor.x, floor.y = 0,0
    floor.m:setRectTex(1,floor.x,floor.y,tw/w,th/h)

end

function floor.move(v)
    floor.x = (floor.x + v.x)%w
    floor.y = (floor.y + v.y)%h
    
end

function floor.draw(e)
    pushMatrix()
    translate(floor.x, floor.y,0)
    floor.m.shader.eye=e
    floor.m.shader.modelMatrix=modelMatrix()
    floor.m:draw()
    popMatrix()
end

TilerShader={vs=[[
    uniform mat4 modelViewProjection;
    uniform mat4 modelMatrix;    
        
    attribute vec4 position;
    attribute vec4 color;
    attribute vec2 texCoord;
    
    varying lowp vec4 vColor;
    varying highp vec2 vTexCoord;
    varying lowp vec4 vPosition;
        
    void main()
    {
        vColor = color;
        vTexCoord = texCoord;
        vPosition = modelMatrix * position;
        //vDist = clamp(1.0-(vPosition.y-eye.y)/fogRadius+0.1, 0.0, 1.1); // (vPosition.y-eye.y) distance(vPosition.xyz, eye.xyz)
        gl_Position = modelViewProjection * position;
    }
    ]],fs=[[
    precision highp float;
    
    uniform lowp sampler2D texture;
    uniform lowp vec4 aerial; //aerial perspective
    uniform vec4 eye;  //xyz1
    uniform float fogRadius;
            
    varying lowp vec4 vColor;
    varying highp vec2 vTexCoord;
    varying lowp vec4 vPosition;
        
    void main()
    {
        lowp vec4 pixel = texture2D( texture, vec2(fract(vTexCoord.x), fract(vTexCoord.y)) ) * vColor;
        float dist = clamp(1.0-distance(vPosition.xyz, eye.xyz)/fogRadius+0.1, 0.0, 1.1); //
        lowp vec4 col = mix(aerial, pixel, dist*dist);  
        //col.a = pixel.a;
        gl_FragColor = col;
    }
    ]]}
    
--# Shader
--Shaders
FrameBlendNoTex = { --models with no texture image
    splineVert= --vertex shader with catmull rom spline interpolation of key frames
    [[ 

    uniform mat4 modelViewProjection;
    uniform mat4 modelMatrix;
    uniform float ambient; // --strength of ambient light 0-1
    uniform vec4 eye; // -- position of camera (x,y,z,1)
    uniform vec4 light; //--directional light direction (x,y,z,0)
    uniform vec4 lightColor;

    uniform int frames[4]; //contains indexes to 4 frames needed for CatmullRom
    uniform float frameBlend; // how much to blend by
    float frameBlend2 = frameBlend * frameBlend; //pre calculated squared and cubed for Catmull Rom
    float frameBlend3 = frameBlend * frameBlend2;
    
    attribute vec4 color;

    attribute vec3 position;
    attribute vec3 position1;
    attribute vec3 position2; //not possible for attributes to be arrays in Gl Es2.0 
    attribute vec3 position3;
    attribute vec3 position4;
    attribute vec3 position5;
    attribute vec3 position6;
        
    attribute vec3 normal;
    attribute vec3 normal1;
    attribute vec3 normal2;
    attribute vec3 normal3;
    attribute vec3 normal4;
    attribute vec3 normal5;
    attribute vec3 normal6;
      
    varying lowp vec4 vAmbient;
    varying lowp vec4 vColor;
    varying vec4 vDirectDiffuse;
    
    vec3 CatmullRom(float u, float u2, float u3, vec3 x0, vec3 x1, vec3 x2, vec3 x3 ) //returns value between x1 and x2
    {
    return ((2. * x1) + 
           (-x0 + x2) * u + 
           (2.*x0 - 5.*x1 + 4.*x2 - x3) * u2 + 
           (-x0 + 3.*x1 - 3.*x2 + x3) * u3) * 0.5;
    }
    
    void main()
    {       
        vec3 pos[7];
        pos[0] = position;
        pos[1] = position1;
        pos[2] = position2;
        pos[3] = position3;
        pos[4] = position4;
        pos[5] = position5;
        pos[6] = position6;
   
        vec3 nor[7];
        nor[0] = normal;
        nor[1] = normal1;
        nor[2] = normal2;
        nor[3] = normal3;
        nor[4] = normal4;
        nor[5] = normal5;
        nor[6] = normal6;
 
     vec3 framePos = CatmullRom(frameBlend, frameBlend2, frameBlend3, pos[frames[0] ], pos[frames[1] ], pos[frames[2] ], pos[frames[3] ] ); // nb must have space between 2 ] ]
       vec3 frameNorm = CatmullRom(frameBlend, frameBlend2, frameBlend3, nor[frames[0] ], nor[frames[1] ], nor[frames[2] ], nor[frames[3] ] );
    
        vec4 norm = normalize(modelMatrix * vec4( frameNorm, 0.0 ));

        vDirectDiffuse = lightColor * max( 0.0, dot( norm, light )); // direct color  vec4(1.0,1.0,1.0,1.0) 
        vAmbient = color * ambient;
        vAmbient.a = 1.; 
        vColor = color; 

        gl_Position = modelViewProjection * vec4(framePos, 1.);
    }
    
    ]],

    linearVert= --vertex shader with linear interpolation of key frames
    [[
    
    uniform mat4 modelViewProjection;
    uniform mat4 modelMatrix;
    uniform float ambient; // --strength of ambient light 0-1
    uniform vec4 eye; // -- position of camera (x,y,z,1)
    uniform vec4 light; //--directional light direction (x,y,z,0)
    uniform vec4 lightColor;
    
    uniform int frames[4]; //linear interpolation only uses the middle 2 values of this array. i wanted interface to be the same as the splineShader
    uniform float frameBlend; // how much to blend by
 
    attribute vec4 color;

    attribute vec3 position;
    attribute vec3 position1;
    attribute vec3 position2; //not possible for attributes to be arrays in Gl Es2.0 
    attribute vec3 position3;
    attribute vec3 position4;
    attribute vec3 position5;
    attribute vec3 position6;
        
    attribute vec3 normal;
    attribute vec3 normal1;
    attribute vec3 normal2;
    attribute vec3 normal3;
    attribute vec3 normal4;
    attribute vec3 normal5;
    attribute vec3 normal6;
    
    varying lowp vec4 vAmbient;
    varying lowp vec4 vColor;
    varying vec4 vDirectDiffuse;
    
    void main()
    {
        vec3 pos[7];
        pos[0] = position;
        pos[1] = position1;
        pos[2] = position2;
        pos[3] = position3;
        pos[4] = position4;
        pos[5] = position5;
        pos[6] = position6;
   
        vec3 nor[7];
        nor[0] = normal;
        nor[1] = normal1;
        nor[2] = normal2;
        nor[3] = normal3;
        nor[4] = normal4;
        nor[5] = normal5;
        nor[6] = normal6;

        vec3 framePos = mix(pos[frames[2] ], pos[frames[3] ], frameBlend);
        vec3 frameNorm = mix(nor[frames[2] ], nor[frames[3] ], frameBlend);
       
        vec4 norm = normalize(modelMatrix * vec4( frameNorm, 0.0 ));
        vDirectDiffuse = lightColor * max( 0.0, dot( norm, light )); // direct color    
    
        vAmbient = color * ambient;
        vAmbient.a = 1.; 
        vColor = color; 
        gl_Position = modelViewProjection * vec4(framePos, 1.);
    }
    
    ]],
    
    frag = [[
    precision highp float;

    varying lowp vec4 vColor;
    varying lowp vec4 vAmbient;  
    varying vec4 vDirectDiffuse;
    
    void main()
    {
        gl_FragColor=vAmbient + vColor * vDirectDiffuse; //
    }
    
    ]]
    }
    
    FrameBlendTex = { --models with a texture image
    splineVert=
    [[
    
    uniform mat4 modelViewProjection;
    uniform mat4 modelMatrix;
    uniform float ambient; // --strength of ambient light 0-1
    uniform vec4 eye; // -- position of camera (x,y,z,1)
    uniform vec4 light; //--directional light direction (x,y,z,0)
    uniform vec4 lightColor;

    uniform int frames[4]; //contains indexes to 4 frames needed for CatmullRom
    uniform float frameBlend; // how much to blend by
    float frameBlend2 = frameBlend * frameBlend; //pre-calculated squared and cubed for Catmull Rom
    float frameBlend3 = frameBlend * frameBlend2;
    
    attribute vec4 color;
    attribute vec2 texCoord;
    
    attribute vec3 position;
    attribute vec3 position2; //not possible for attributes to be arrays in Gl Es2.0 
    attribute vec3 position3;
    attribute vec3 position4;
    
    attribute vec3 normal;
    attribute vec3 normal2;
    attribute vec3 normal3;
    attribute vec3 normal4;
    
    vec3 getPos(int no) //home-made hash, ho hum.  
    {
        if (no==1) return position;
        if (no==2) return position2;
        if (no==3) return position3;
        if (no==4) return position4;
    }
    
    vec3 getNorm(int no)
    {
        if (no==1) return normal;
        if (no==2) return normal2;
        if (no==3) return normal3;
        if (no==4) return normal4;
    }
          
    varying lowp vec4 vAmbient;
    varying lowp vec4 vColor;
    varying highp vec2 vTexCoord;
    varying vec4 vDirectDiffuse;
    
    vec3 CatmullRom(float u, float u2, float u3, vec3 x0, vec3 x1, vec3 x2, vec3 x3 ) //returns value between x1 and x2
    {
    return ((2. * x1) + 
           (-x0 + x2) * u + 
           (2.*x0 - 5.*x1 + 4.*x2 - x3) * u2 + 
           (-x0 + 3.*x1 - 3.*x2 + x3) * u3) * 0.5;
    }
    
    void main()
    {       
        vec3 framePos = CatmullRom(frameBlend, frameBlend2, frameBlend3, getPos(frames[0]), getPos(frames[1]), getPos(frames[2]), getPos(frames[3]) );
       vec3 frameNorm = CatmullRom(frameBlend, frameBlend2, frameBlend3, getNorm(frames[0]), getNorm(frames[1]), getNorm(frames[2]), getNorm(frames[3]) );
    
        vec4 norm = normalize(modelMatrix * vec4( frameNorm, 0.0 ));
        vDirectDiffuse = lightColor * max( 0.0, dot( norm, light )); // direct color  vec4(1.0,1.0,1.0,1.0)
    
        vAmbient = color * ambient;
        vAmbient.a = 1.; 
        vColor = color; 
        vTexCoord = texCoord;
        gl_Position = modelViewProjection * vec4(framePos, 1.);
    }
    
    ]],

    linearVert=
    [[  
    uniform mat4 modelViewProjection;
    uniform mat4 modelMatrix;
    uniform float ambient; // --strength of ambient light 0-1
    uniform vec4 eye; // -- position of camera (x,y,z,1)
    uniform vec4 light; //--directional light direction (x,y,z,0)
    uniform vec4 lightColor;
    
    uniform int frames[4]; //linear interpolation only uses the middle 2 values of this array. i wanted interface to be the same as the splineShader
    uniform float frameBlend; // how much to blend by
 
    attribute vec4 color;
    attribute vec2 texCoord;   
    
    attribute vec3 position;
    attribute vec3 position2; //not possible for attributes to be arrays in Gl Es2.0 
    attribute vec3 position3;
    attribute vec3 position4;
    
    attribute vec3 normal;
    attribute vec3 normal2;
    attribute vec3 normal3;
    attribute vec3 normal4;
    
    vec3 getPos(int no) //home-made hash, ho hum.  
    {
        if (no==1) return position;
        if (no==2) return position2;
        if (no==3) return position3;
        if (no==4) return position4;
    }
    
    vec3 getNorm(int no)
    {
        if (no==1) return normal;
        if (no==2) return normal2;
        if (no==3) return normal3;
        if (no==4) return normal4;
    }
    
    varying lowp vec4 vAmbient;
    varying lowp vec4 vColor;
    varying highp vec2 vTexCoord;
    varying vec4 vDirectDiffuse;
    
    void main()
    {
        vec3 framePos = mix(getPos(frames[2]), getPos(frames[3]), frameBlend);
        vec3 frameNorm = mix(getNorm(frames[2]), getNorm(frames[3]), frameBlend);
       
        vec4 norm = normalize(modelMatrix * vec4( frameNorm, 0.0 ));

        vDirectDiffuse = lightColor * max( 0.0, dot( norm, light )); // direct color    
        vAmbient = color * ambient;
        vAmbient.a = 1.; 
        vColor = color; 
        vTexCoord = texCoord;

        gl_Position = modelViewProjection * vec4(framePos, 1.);
    }
    
    ]],
    
    frag = [[
    
    precision highp float;
    
    uniform lowp sampler2D texture;

    varying lowp vec4 vColor;
    varying highp vec2 vTexCoord;
    varying lowp vec4 vAmbient;   
    varying vec4 vDirectDiffuse;
    
    void main()
    {
        vec4 pixel= texture2D( texture, vTexCoord ); // * vColor nb color already included in ambient
        vec4 ambient = pixel * vAmbient;

        gl_FragColor=ambient + pixel * vDirectDiffuse; 
    }
    
    ]]
}