
--# Main
--3D Model viewer

State={Ready=1,Loading=2,Error=3}
ready = false
function setup() 
    linearShader=shader(FrameBlendNoTex.linearVert, FrameBlendNoTex.frag)
    splineShader=shader(FrameBlendNoTex.splineVert, FrameBlendNoTex.frag)
    parameter.watch("FPS")
 --   parameter.number("frame",1,5,1) --slider for scrubbing through animation by hand
    parameter.integer("noOfDudes", 1, 60, 1)
    parameter.integer("Choose",1,#Models,1)
    parameter.action("Load",LoadModel)
    parameter.integer("Zoom",1,300,250)

    parameter.integer("X",-180,180,0)
    parameter.integer("Y",-180,180,0)
    parameter.integer("Z",-180,180,0)

    parameter.integer("panX",-180,180,0)
  --  parameter.integer("panY",-180,180,0)
    parameter.integer("panZ",-180,180,90)
    parameter.action("DeleteStoredData",DeleteData)

    FPS=0

    --print model list
  --  output.clear()
    for i=1,#Models do print(i,Models[i].name) end
    state=State.Ready
end

function LoadModel() --replaces the function in Main
    state=State.Loading
    model=Rig(Models[Choose].name,Models[Choose].url)
    oldDraw=draw
    draw=loadDraw
end

function DeleteData()
   if model then model:DeleteData() end
end

function loadDraw()
    if state==State.Loading then
        if model then model:load() end --and ready then ConfigureModel() end
        return 
    end 
end

function draw()
    background(116, 173, 182, 255)
    FPS=FPS*0.9+0.1/DeltaTime

    perspective()
    camera(15,Zoom,panZ, panX,-Zoom,panZ, 0,0,1)
    pushMatrix()
    
    rotate(X,1,0,0)
    rotate(Y,0,1,0)
    rotate(Z,0,0,1)
    if model then
        for i=1, noOfDudes do
            
            local eye=vec4(0,0,Zoom,1)
            if animate then model:anim(i*0.2) end
            model:draw(eye)
            translate(5,-40,0)
        end
    end
    popMatrix()
    if touchPos then setContext() end
end

function touched(t)
    if t.state==ENDED then 
        animate=false 
    elseif t.state==BEGAN then 
        model:cueAnim(true, 1,2,3,4)
        animate=true 
    end
end

--# Assets
--Assets
Models={

{name="captainCodea",
url={
"https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodea_000030.mtl",
"https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodea_000030.obj",
"https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodea_000035.obj",
"https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodea_000040.obj",
"https://raw.githubusercontent.com/Utsira/assets/master/CaptainCodea_000045.obj"
}},

{name="robot",
url={

"https://raw.githubusercontent.com/Oliver-D/models/master/robot-c90_000000.mtl",
"https://raw.githubusercontent.com/Oliver-D/models/master/robot-c90_000000.obj",
"https://raw.githubusercontent.com/Oliver-D/models/master/robot-c90_000007.obj",
"https://raw.githubusercontent.com/Oliver-D/models/master/robot-c90_000014.obj",
"https://raw.githubusercontent.com/Oliver-D/models/master/robot-c90_000021.obj",
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
                self:LoadImages() 
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

function GetColor(n)
    local b=math.fmod(n,256)
    local a=(n-b)/255
    return color(a,b,0)
end
--# Rig
Rig = class() --load and concatenate all the obj and mtl files into a single mesh, and animate it

function Rig:init(name, url)
    self.mtl = MTL(name.."mtl", url[1])  --the mtl material file
    self.obj = {}

    for i=2,#url do
        local fr=i-1
        self.obj[fr]=OBJ(name..fr, url[i], self.mtl) --the obj files (nb pass them the material file)    
    end
    print (#self.obj.." frames")
end

function Rig:draw(e)
    self.mesh.shader.modelMatrix=modelMatrix() --part of lighting
    self.mesh.shader.eye=e
    self.mesh:draw()
end

function Rig:cueAnim(loop, ...)
    self.frames = {...}
    self.frame = 0
    local args
    if loop then args = {loop=tween.loop.forever} end
    tween(1.5, self, {frame=#self.frames}, args) -- -0.00001 --1.5
    print ("frames "..#self.frames)
    
        --add frames   
    local m = self.mesh 
    local pos={m:buffer("position2"), m:buffer("position3"), m:buffer("position4")}
    local norm = {m:buffer("normal2"), m:buffer("normal3"), m:buffer("normal4")}

    for i=2, #self.obj do
        local frame=self.obj[i]
        --pos[i-1]:set(frame.v) --crashes codea
       -- norm[i-1]:set(frame.n)
        
        for j=1,#frame.v do
           local v = frame.v[j]
            pos[i-1][j]=vec3(v.x,v.y,v.z) --nb must make an independent copy of the vector
            local n = frame.n[j]
            norm[i-1][j]=vec3(n.x,n.y,n.z)
        end
        
        print ("added frame "..i)
    end
end

function Rig:anim(offset)
    local start, frac = math.modf(self.frame+offset) --self.frame find the start frame (indexed to 0 for modulation) and the frameBlend fraction   
    self.mesh.shader.frameBlend = frac --set frame interpolation fraction
    local len=#self.frames
    local fr={}
    for i=0, 3, 1 do --walk through 4 frames (0=start-1, 1=start frame, 2=start+1, 3=start+2)
        local j = (start + (i - 1))%len --work out where in self.frame to point, use mod to wrap, index 0 because of mod
        fr[i+1]=self.frames[j+1]-1
    end    
    self.mesh.shader.frames={fr[1],fr[2],fr[3],fr[4]}
end

function Rig:load()  --call every frame during loading. Handles asyncronous loading of files
    local loadCount=0
    for i=1,#self.obj do      
        local v=self.obj[i]    
        if self.mtl.state=="processed" and v.state=="hasData" then --if mtl file has processed and obj file loaded, then ...        
            v:ProcessData() --can start processing obj files     
        end
        if v.state=="processed" then
            loadCount = loadCount + 1
        end
    end
    if self.mtl.ready and loadCount==#self.obj then --if all files have processed and images have loaded then can build mesh
        self:BuildMesh()
      --  self:cueAnim(true, 1,2,3,4)
    end
end

function Rig:BuildMesh() --concatenate files into mesh
    print("buildingMesh")
    local m=mesh()
    local mtl=self.mtl
    local obj=self.obj[1] --first obj file is the master
    obj.state="building" --prevent repeat build calls in case load is still running
     print (#obj.v.." vertices")
    m.vertices=obj.v
   
    if #obj.t>0 then m.texCoords=obj.t end
    if #obj.n>0 then m.normals=obj.n end
    if #obj.c>0 then m.colors=obj.c end -- new: set vertex colors
    
    m.shader=splineShader -- linearShader -- 
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
       
    state=State.Ready
    draw=oldDraw
    print("ready")
end

function Rig:DeleteData()
    for i,v in ipairs(self.obj) do
        v:DeleteData()
    end
    self.mtl:DeleteData()
end

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
    attribute vec3 position2; //not possible for attributes to be arrays in Gl Es2.0 
    attribute vec3 position3;
    attribute vec3 position4;
    attribute vec3 position5;
    attribute vec3 position6;
    attribute vec3 position7;

    attribute vec3 normal;
    attribute vec3 normal2;
    attribute vec3 normal3;
    attribute vec3 normal4;
    attribute vec3 normal5;
    attribute vec3 normal6;
    attribute vec3 normal7;
      
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
    
  //  uniform vec3 positions[4] = vec3[4]( vec3(1.), vec3(1.), vec3(1.), vec3(1.)); //( position, position2, position3, position4);
  //  uniform float pos[4] = float[4]( 1., 1., 1., 1.); //( position, position2, position3, position4);
    void main()
    {       
        vec3 pos[7];
        pos[0] = position;
        pos[1] = position2;
        pos[2] = position3;
        pos[3] = position4;
        pos[4] = position5;
        pos[5] = position6;
        pos[6] = position7;
   
        vec3 nor[7];
        nor[0] = normal;
        nor[1] = normal2;
        nor[2] = normal3;
        nor[3] = normal4;
        nor[4] = normal5;
        nor[5] = normal6;
        nor[6] = normal7;
 
     vec3 framePos = CatmullRom(frameBlend, frameBlend2, frameBlend3, pos[frames[0] ], pos[frames[1] ], pos[frames[2] ], pos[frames[3] ] );
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
