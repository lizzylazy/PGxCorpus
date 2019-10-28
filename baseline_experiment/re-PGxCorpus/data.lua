require 'torch'
require "paths"

function copy_tab(tab)
   local res = {}
   for i=1,#tab do
      table.insert(res, tab[i]) 
   end
   return res
end

local anon_res = torch.FloatTensor()
function anon_getent(words, entities, e1, e2, data)
   anon_res:resize(words:size(1)):fill( data.entityhash2.O)
   --printw(data.words[nsent], data.wordhash)
   --print(nsent)
   --print(data.words[nsent])
   --print(data.entities[nsent])
   local ent1 = entities[e1][6]
   local ent2 = entities[e2][6]
   --print(ent1)
   --print(ent2)
   for i=1,#ent1 do anon_res[ ent1[i] ]=data.entityhash2.Entity1 end
   for i=1,#ent2 do anon_res[ ent2[i] ]=data.entityhash2.Entity2 end
   return anon_res
end

local anon_res2 = torch.FloatTensor()
function anon_getenttags(data, words, entities, e1, e2)
   anon_res2:resize(words:size(1)):fill(data.entityhash["O"])--create input tensor
   local _type1 = entities[e1][2]
   local _type2 = entities[e2][2]
   local ent1 = entities[e1][6]
   local ent2 = entities[e2][6]
   for i=1,#ent1 do anon_res2[ ent1[i] ] = data.entityhash[_type1] end--entity1
   for i=1,#ent2 do anon_res2[ ent2[i] ] = data.entityhash[_type2] end--entity2
   return anon_res2
end

local anon_res_nestenttype = {}
function anon_getnestenttype(data, words, entities, e1, e2)
   --print(entities[e1])
   --print(entities[e2])
	 
   local nest_e1 = is_nested_in(entities[e1], data.entityhash)
   local nest_e2 = is_nested_in(entities[e2], data.entityhash)
   --print(nest_e1)
   --print(nest_e2)
   local ent1 = entities[e1][6]
   local ent2 = entities[e2][6]
   
   --print(ent1)
   --print(ent2)
   for i=3,#data.entityhash do --not for padding and Other
      --print(data.entityhash[i] .. " (" .. i .. ")")
      anon_res_nestenttype[i-2] = anon_res_nestenttype[i-2] or torch.Tensor()
      anon_res_nestenttype[i-2]:resize(words:size(1)):fill(2) --1 for Padding 2 for not present 3 for present
      for j=1,#ent1 do anon_res_nestenttype[i-2][ ent1[j] ] = nest_e1[i] and 3 or 2 end
      for j=1,#ent2 do anon_res_nestenttype[i-2][ ent2[j] ] = nest_e2[i] and 3 or 2 end
      -- for k=1,anon_res_nestenttype[i-2]:size(1) do
      -- 	 io.write(anon_res_nestenttype[i-2][k] .. " ")
      -- end
      -- io.write("\n")
      --print(res_nestenttype[i-2]:clone():resize(1, res_nestenttype[i-2]:size(1)))
   end
   --io.read()
   return anon_res_nestenttype
end


function anonymize(words, entities, ent1, ent2, data, params)
   --printw(words, data.wordhash)
   --print(entities[ent1])
   --print(entities[ent2])
   
   --first entity in first
   -- if entities[ent1][5][1]>entities[ent2][5][1] then
   --    local back = ent1
   --    ent1 = ent2
   --    ent2 = back
   -- end
   
   local _ws = {}
   for w=1,words:size(1) do
      table.insert(_ws, words[w])
   end
   --print(entities[1])
   
   entities[ent1][6] = copy_tab(entities[ent1][5])
   entities[ent2][6] = copy_tab(entities[ent2][5])
   
   --print("==================")
   --print(entities[ent1][4])
   --print(entities[ent2][4])
   --print(entities[ent1][6])
   --print(entities[ent2][6])
   
   
   --replacing ent1 with special token "entity"
   local new_ent = {}
   while entities[ent1][6][1] do
      --getting groups of consecutive entity words
      local group_e = {}
      local current_e = table.remove(entities[ent1][6],1) 
      table.insert(group_e, current_e)
      while entities[ent1][6][1]==current_e+1 do
	 current_e = table.remove(entities[ent1][6],1)
	 table.insert(group_e, current_e)
      end
      --print("group")
      --print(group_e)
      table.insert(new_ent, group_e[1])
      --printw(torch.Tensor(_ws), data.wordhash)
      for i=1,#group_e do
	 table.remove(_ws, group_e[1])
      end
      table.insert(_ws, group_e[1], 4)
      --printw(torch.Tensor(_ws), data.wordhash)
      --updating word indices for all the other words of the entities
      for k=1,#entities[ent1][6] do
	 if entities[ent1][6][k]>group_e[1] then
	    entities[ent1][6][k] = entities[ent1][6][k]-#group_e+1
	 end
      end
      --updating word indices for the other entity
      for k=1,#entities[ent2][6] do
	 if entities[ent2][6][k]>group_e[1] then
	    entities[ent2][6][k] = entities[ent2][6][k]-#group_e+1
	 end
      end
   end
   entities[ent1][6] = new_ent
   -- io.read()
   
   -- print(entities[ent1][6])
   -- print(entities[ent2][6])
   
   --replacing ent2 with special token "entity"
   --print(entities[ent2][6])
   local new_ent = {}
   while entities[ent2][6][1] do
      --getting groups of consecutive entity words
      local group_e = {}
      local current_e = table.remove(entities[ent2][6],1) 
      table.insert(group_e, current_e)
      while entities[ent2][6][1]==current_e+1 do
	 current_e = table.remove(entities[ent2][6],1)
	 table.insert(group_e, current_e)
      end
      --print(group_e)
      table.insert(new_ent, group_e[1])
      --printw(torch.Tensor(_ws), data.wordhash)
      for i=1,#group_e do
	 table.remove(_ws, group_e[1])
      end
      table.insert(_ws, group_e[1], 5)
      --printw(torch.Tensor(_ws), data.wordhash)
      --updating word indices for all the other words of the entities
      for k=1,#entities[ent2][6] do
	 if entities[ent2][6][k]>group_e[1] then
	    entities[ent2][6][k] = entities[ent2][6][k]-#group_e+1
	 end
      end
      --updating word indices for the other entity
      for k=1,#entities[ent1][6] do
	 if entities[ent1][6][k]>group_e[1] then
	    entities[ent1][6][k] = entities[ent1][6][k]-#group_e+1
	 end
      end
   end
   entities[ent2][6] = new_ent
   --io.read()

   --print(_ws)
   local new_words = torch.Tensor(_ws)
   
   local ents1 = anon_getent(new_words, entities, ent1, ent2, data)
   --printw(ents1, data.entityhash2)

   local ents2 = anon_getenttags(data, new_words, entities, ent1, ent2)
   --printw(ents2, data.entityhash)
   --io.read()
   
   local new_input = {new_words}
   if params.tfsz>0 then
      table.insert(new_input, ents2)
   end
   
   if params.rdfsz and params.rdfsz~=0 then
      table.insert(new_input, data.get_relative_distance(ents1, 1))
      table.insert(new_input, data.get_relative_distance(ents1, 2))
   end

   if params.nestenttype>0 then
      local nests = anon_getnestenttype(data, new_words, entities, ent1, ent2)
      --print(nests)
      for i=1,#nests do
	 table.insert(new_input, nests[i])
      end
   end
   table.insert(new_input, ents1)
   return new_input
end

local function loadnames(pathdata, maxload)
   print("loading names in " .. pathdata)
   local indices = {}
   local handle = io.popen("export LC_ALL=C; find " .. pathdata .. " -name '*.txt' | sort")
   
   local filename = handle:read()
   while filename do
      --print(string.format('loading <%s>', filename))
      
      if maxload and maxload > 0 and maxload == #indices then
	 print("breakdata1")
	 break
      end
      table.insert(indices, filename:match("/(%d+_%d+).txt"))
      filename = handle:read()
   end
   handle:close()
   collectgarbage()
   return indices
end


function _setlevel(node, contiguous)
   --print("---- " .. node[3])
   if #node.sons==0 then
      if contiguous and #node[1]>1 then --discontiguous entity
	 --print(node[3] .. ' 1')
	 node.level = 0
	 return node.level
      else
	 --print(node[3] .. ' 2')
	 node.level=1
	 return node.level
      end
   else
      local max_son = 0
      for i=1,#node.sons do
	 max_son = math.max(max_son, _setlevel(node.sons[i], contiguous))
      end
      if contiguous and #node[1]>1 then --discontiguous entity
	 --print(node[3] .. ' 3')
	 node.level = 0
	 return max_son
      else
	 --print(node[3] .. ' 4')
	 node.level = 1 + max_son
	 return 1 + max_son
      end
   end
end
   
--compute level in dag
--contiguous option allow to discard discontiguous entities
function setlevel(ent, contiguous)
   --printdag(ent)
   --for i=1,#ent do
   --   print(ent[1])
   --end
   for i=1,#ent do
      --print("=============" .. i)
      _setlevel(ent[i], contiguous)
   end
end

--
function is_nested_in(ent, entityhash)
   local res = {}
   _is_nested_in(ent, entityhash, res)
   return res
end

function _is_nested_in(ent, entityhash, res)
   for i=1,#ent.sons do
      res[entityhash[ ent.sons[i][2] ]] = true
      --res[ ent.sons[i][2] ] = true
      _is_nested_in(ent.sons[i], entityhash, res)
   end
end

function _load_entity_indices(ents, starts, ends)
   --print("============")
   --print(ents)
   
   --printw(words[i], wordhash)
   --print(words.sent[i])
      --print(starts)
   --print(ends)
   
   for j=1,#ents do
      --idx: word indices corresponding to the entity
      local idx = {}
      --print(ents[j])
      for e=1,#ents[j][1] do
	 local _start, _end
	 for _s=1, starts:size(1) do
	    --print(starts[_s]+(_s-1) .. " " .. ents[j][1][e][1])
	    -- (+ _s-1) to include spaces between words
	    if starts[_s]+(_s-1)==ents[j][1][e][1] then --start found
	       --print("start found " .. _s)
	       _start = _s
	    end
	 end
	 assert(_start, "_start not found")
	 --print("start " .. _start)
	 for _e=_start, ends:size(1) do
	    --print(ends[_e]+_e .. " " .. ents[j][1][e][2])
	    -- (+ _e) to include spaces between words
	    if ends[_e]+_e==ents[j][1][e][2] then
	       --print("end found " .. _e)
	       _end = _e
	    end
	 end
	 assert(_end, "_end not found")
	 --print(_start .. " " .. _end)
	 for i=_start, _end do
	    table.insert(idx, i)
	 end
      end

      table.sort(idx, function(a,b) return a<b end)
      ents[j][5] = idx
      --print(ents[j])
      --io.read()
   end
end

local function load_entity_indices(entities, words, starts, ends, wordhash, names)
   assert(#entities==#words.idx and #entities==#starts and #entities==#ends, #entities .. " " .. #words.idx .. " " .. #starts .. " " .. #ends)

   for i=1,#entities do
      --printw(words[i], wordhash)
      _load_entity_indices(entities[i], starts[i], ends[i])
   end   
end


local function loadstartend(pathdata, feature, maxload)
   print("loading startend in " .. pathdata)
   local starts = {}
   local ends = {}
   local _break = false

   local handle = io.popen("export LC_ALL=C; find " .. pathdata .. " -name '*.txt' | sort")
   local filename = handle:read()
   while filename do
      --print(string.format('loading startend for <%s>', filename))
      for line in io.lines(filename) do
	 --print(line)
	 if maxload and maxload > 0 and maxload == #starts then
	    print("break")
	    _break = true
	    break
	 end
	 if line~="" then
	    local s, e = {}, {}
	    local i = 0
	    for word in line:gmatch('(%S+)') do
	       table.insert(s, i)
	       --print(word)
	       --print(#word)
	       i = i + #word
	       table.insert(e, i-1)
	    end
	    table.insert(starts, torch.IntTensor(s))
	    table.insert(ends, torch.IntTensor(e))
	    --local t = torch.IntTensor(s) 
	    --print(t:resize(1,t:size(1)))
	    --local t2 = torch.IntTensor(e) 
	    --print(t2:resize(1,t2:size(1)))
	 end
	 --io.read()
      end
      filename = handle:read()
      if _break then print("break 1"); break end
   end
   handle:close()
   return starts, ends
end


function loaddag(entities)
   local indices = {}
   for i=1,#entities do
      getdag(entities[i])
   end
   return indices
end

--build an inclusion dag (directed acyclic graph)
function getdag(ent)
   for ent1=1,#ent do
      ent[ent1].sons = {}
   end
   
   for ent1=1,#ent do
      for ent2=1,#ent do
	 --print("=====================================> " .. ent1 .. " " .. ent2)
	 if ent1~=ent2 and is_included(ent[ent1][1], ent[ent2][1]) and is_included(ent[ent2][1], ent[ent1][1]) then
	    if ent1<ent2 then
	       table.insert(ent[ent2].sons, ent[ent1])
	    end
	 elseif ent1~=ent2 and is_included(ent[ent1][1], ent[ent2][1]) then
	    --print(ent1 .. " is included in " .. ent2)
	    table.insert(ent[ent2].sons, ent[ent1])
	    --io.read()
	 end
	 
      end
   end
end

--return true if ent1 overlapp with ent2
--ent1 and ent2 must be list of word indices
function overlapp(ent1, ent2)
   for i=1,#ent1 do
      for j=1,#ent2 do
	 if ent1[i]==ent2[j] then return true end
      end
   end
   return false
end

--return true if ent1 in included in ent2
function is_included(ent1, ent2)
   local res = true
   -- print("====")
   -- print(ent1)
   -- print(ent2)
   
   for i=1, #ent1 do
      local found  = false
      for j=1,#ent2 do
	 local b1, e1 = ent1[i][1], ent1[i][2] --note: change that to include uncontiguous entities
	 local b2, e2 = ent2[j][1], ent2[j][2]
	 if type(b1)=="string" then error("") end
	 if b2<=b1 and e2>=e1 then found = true end
      end
      res = res and found
   end
   -- print("is_included")
   -- print(res)
   return res
end



local function tree2tree(trees)
   --print(string.format('tree2tree'))
   local newtrees = {}
   for i=1,#trees do
      local tree = trees[i]
      --print(tree)
      local reps = {}
      local j = 1
      while j<#tree do
	 local size = tree[j]
	 j = j+1
	 local head = treelstm.Tree()
	 head.idx = tree[j]
	 j = j + 1
	 for k=1,size-1 do
	    if tree[j]<1000 then
	       local son = treelstm.Tree()
	       son.idx = tree[j]
	       head:add_child(son)
	    else
	       head:add_child(reps[ tree[j]-1000 ])
	    end
	    j = j + 1
	 end
	 table.insert(reps, head)
      end
      for i=1,#reps do
	 --print(i)
	 --reps[i]:print()
      end
      -- print("==============")
      -- reps[#reps]:print()
      table.insert(newtrees, reps[#reps])
      --io.read()
   end
   return newtrees
end

local function loadtrees(filename, maxid)
   print(string.format('loading <%s>', filename))
   local trees = {}
   for line in io.lines(filename) do
      if line~="" then
	 if maxload and maxload > 0 and maxload == #trees then
	    print("breakdata10")
	    break
	 end
	 local tab = {}
	 for word in line:gmatch('(%d+)') do
	    table.insert(tab, tonumber(word))
	 end
	 table.insert(trees, tab)
      end
   end
   return trees
end

local function _loadhash(filename, maxidx)
   print(string.format('loading <%s>', filename))
   local hash = {}
   local idx = 0
   for key in io.lines(filename) do
      idx = idx + 1
      if maxidx and maxidx > 0 and idx > maxidx then
         break
      end
      table.insert(hash, key)
      hash[key] = idx
   end
   return hash
end

local function _addhash(filename, hash)
   print(string.format('adding <%s> to hash', filename))
   local idx = #hash
   local _added, _present = 0, 0
   for key in io.lines(filename) do
      if not hash[key] then
	 _added = _added + 1
	 idx = idx + 1
	 table.insert(hash, key)
	 hash[key] = idx
      else
	 _present = _present + 1
      end
   end
   print(_added .. " words added, " .. _present .. " words already in hash")
   return hash
end

local function wordfeature(word)
   word = word:lower()
   word = word:gsub('%d+', '0')
   return word
end

local function loadindices(filename, maxload)
   print(string.format('loading <%s>', filename))
   local res = {}
   for line in io.lines(filename) do
      table.insert(res, line)
   end
   return res
end

local function loadwords(pathdata, hash, addraw, feature, maxload)

   maxidx = maxidx or #hash
   local lines = addraw and {} or nil
   local indices = {}
   local sentences = {}
   local _break = false
   
   local handle = io.popen("export LC_ALL=C; find " .. pathdata .. " -name '*.txt' | sort")
   local filename = handle:read()
   while filename do
      --print(string.format('loading <%s>', filename))
      for line in io.lines(filename) do
	 --print(line)
	 if line~="" then
	    if maxload and maxload > 0 and maxload == #indices then
	       print("breakdata2")
	       _break = true
	       break
	    end
	    table.insert(sentences, line)
	    local words = {}
	    local wordsidx = {}
	    for word in line:gmatch('(%S+)') do
	       if addraw then
		  table.insert(words, word)
	       end
	       table.insert(wordsidx, hash[feature and feature(word) or word] or hash.UNK)
	    end
	    if addraw then
	       table.insert(lines, words)
	    end   
	    
	    table.insert(indices, torch.IntTensor(wordsidx))
	 end
      end
      filename = handle:read()
      if _break then print("break 1"); break end
   end
   handle:close()
   print("nb line " .. #indices)
   collectgarbage()
   return {raw=lines, idx=indices, sent=sentences}
end


local function loadwords_back(filename, hash, addraw, feature, maxload)
   print(string.format('loading <%s>', filename))
   local lines = addraw and {} or nil
   local indices = {}
   local sentences = {}
   for line in io.lines(filename) do
      local l = line:gsub(" +", " ")
      table.insert(sentences, l)
      if line~="" then
	 if maxload and maxload > 0 and maxload == #indices then
	    print("breakdata10")
	    break
	 end
	 local words = {}
	 local wordsidx = {}
	 for word in line:gmatch('(%S+)') do
	    if addraw then
	       table.insert(words, word)
	    end
	    table.insert(wordsidx, hash[feature and feature(word) or word] or hash.UNK)
	 end
	 if addraw then
	    table.insert(lines, words)
	 end
	 
	 table.insert(indices, torch.Tensor(wordsidx))
      end
   end

   --print("nb line " .. #indices)

   --print(lines)
   
   collectgarbage()
   return {raw=lines, idx=indices, sent=sentences}
end

local function idx(tbl)
   setmetatable(tbl, {__index = function(self, idx)
			 return self.idx[idx]
   end})
end

local function pad(tbl, sz, val)
   setmetatable(tbl, {__index = function(self, idx)
			 local x = self.idx[idx]
			 local px = torch.Tensor(x:size(1)+2*sz):fill(val)
			 px:narrow(1, sz+1, x:size(1)):copy(x)
			 return px
   end})
end

local function loadentities(pathdata, extention, params, entityhash)
   local entities = {}
   local mapping = {}
   
   local handle = io.popen("export LC_ALL=C; find " .. pathdata .. " -name '*" .. extention .. "' | sort")
   local filename = handle:read()
   while filename do
      --print(string.format('loading caps for <%s>', filename))
      if params.maxload and params.maxload > 0 and params.maxload == #entities then
	 break
      end

      local ent = {}
      local map = {}
      for line in io.lines(filename) do
	 if line:match("^T%d") then
	    local _ent = line:match("^(T%d+)")
	    local n_ent = _ent:match("%d+")
	    local _w2 = line:match("^T%d+\t[^ ]+ %d+[^\t]+%d+\t(.*)")
	    local _type = line:match("^T%d+\t([^ ]+) %d+ %d+")
	    local bounds = line:match("^T%d+\t[^ ]+ (%d+[^\t]+%d+)")
	    local _bounds = {}
	    for b,e in bounds:gmatch("(%d+) (%d+)") do
	       table.insert(_bounds, {tonumber(b),tonumber(e)})
	    end
	    -- local _start = line:match("^T%d+\t[^ ]+ (%d+)")
	    -- local _end = line:match("^T%d+\t[^ ]+ %d+ (%d+)")
	    
	    table.insert(ent, {_bounds, _type, _ent, _w2})
	    map[tonumber(n_ent)] = #ent
	 end
      end

      -- print(ent)
      -- io.read()
      table.insert(entities, ent)
      table.insert(mapping, map)
      
      filename = handle:read()
   end


   local res = torch.Tensor()
   entities.getent = function(data, nsent, e1, e2)
      res:resize(data.words[nsent]:size(1)):fill( data.entityhash2.O )
      --printw(data.words[nsent], data.wordhash)
      --print(nsent)
      --print(data.words[nsent])
      --print(data.entities[nsent])
      local ent1 = data.entities[nsent][e1][5]
      local ent2 = data.entities[nsent][e2][5]
      for i=1,#ent1 do res[ ent1[i] ]= data.entityhash2.Entity1 end
      for i=1,#ent2 do res[ ent2[i] ]=data.entityhash2.Entity2 end
      return res
   end
   
   local res2 = torch.Tensor()
   entities.getenttags = function(data, nsent, e1, e2)
      res2:resize(data.words[nsent]:size(1)):fill(data.entityhash["O"])--create input tensor
      local _type1 = data.entities[nsent][e1][2]
      local _type2 = data.entities[nsent][e2][2]
      local ent1 = data.entities[nsent][e1][5]
      local ent2 = data.entities[nsent][e2][5]
      for i=1,#ent1 do res2[ ent1[i] ] = data.entityhash[_type1] end--entity1
      for i=1,#ent2 do res2[ ent2[i] ] = data.entityhash[_type2] end--entity2
      return res2
   end

   local res_nestenttype = {}
   for i=3,#entityhash do
      table.insert(res_nestenttype, torch.Tensor())
   end
   entities.getnestenttype = function(data, nsent, e1, e2)
      --print(data.entities[nsent])
      --print(data.entities[nsent][e1])
      local nest_e1 = is_nested_in(data.entities[nsent][e1], data.entityhash)
      local nest_e2 = is_nested_in(data.entities[nsent][e2], data.entityhash)
      --print(nest_e1)
      --print(nest_e2)
      local ent1 = data.entities[nsent][e1][5]
      local ent2 = data.entities[nsent][e2][5]

      --print(ent1)
      --print(ent2)
      for i=3,#data.entityhash do --not for padding and Other
	 --print(data.entityhash[i] .. " (" .. i .. ")")
       	 res_nestenttype[i-2]:resize(data.words[nsent]:size(1)):fill(2) --1 for Padding 2 for not present 3 for present
      	 for j=1,#ent1 do res_nestenttype[i-2][ ent1[j] ] = nest_e1[i] and 3 or 2 end
	 for j=1,#ent2 do res_nestenttype[i-2][ ent2[j] ] = nest_e2[i] and 3 or 2 end
	 -- for k=1,res_nestenttype[i-2]:size(1) do
	 --    io.write(res_nestenttype[i-2][k] .. " ")
	 -- end
	 -- io.write("\n")
	 --print(res_nestenttype[i-2]:clone():resize(1, res_nestenttype[i-2]:size(1)))
      end
      
      

      --io.read()
      --res2:resize(data.words[nsent]:size(1)):fill(data.entityhash["O"])--create input tensor
      -- local _type1 = data.entities[nsent][e1][2]
      -- local _type2 = data.entities[nsent][e2][2]
      -- local ent1 = data.entities[nsent][e1][5]
      -- local ent2 = data.entities[nsent][e2][5]
      -- for i=1,#ent1 do res2[ ent1[i] ] = data.entityhash[_type1] end--entity1
      -- for i=1,#ent2 do res2[ ent2[i] ] = data.entityhash[_type2] end--entity2
      -- return res2
      return res_nestenttype
   end
   
   
   entities.nent = function(data, nsent)
      return #data.entities[nsent]
   end

   entities.typeent = function(data, nsent, nent)
      return data.entities[nsent][nent][1]
   end

   entities.mapping = mapping
   
   return entities
end


local function loadrelations(pathdata, extention, maxload, hash, params, entities)
   local relations = {}
   local count = 0

   local handle = io.popen("export LC_ALL=C; find " .. pathdata .. " -name '*" .. extention .. "' | sort")
   local filename = handle:read()
   while filename do
      count = count + 1
      relations[count] = {}
      
      if maxload and maxload > 0 and #relations>maxload then
	 break
      end

      --local rel = {}
      for line in io.lines(filename) do
	 if line:match("^R%d") then
	    local ent1 = line:match("^R%d+\t[^ ]+ Arg1:T(%d+)")
	    local ent2 = line:match("^R%d+\t[^ ]+ Arg1:T%d+ Arg2:T(%d+)")
	    local _type = line:match("^R%d+\t([^ ]+) Arg1:T%d+ Arg2:T%d+")
	    ent1 = tonumber(ent1)
	    ent2 = tonumber(ent2)
	    local _ent1 = entities.mapping[count][ent1]
	    local _ent2 = entities.mapping[count][ent2]
	    -- if _ent1>_ent2 then
	    --    local temp = _ent2
	    --    _ent2=_ent1
	    --    _ent1=temp
	    -- end
	    -- assert(_ent1<_ent2)
	    -- if relations[count][_ent1]==nil then relations[count][_ent1]={} end
	    -- relations[count][_ent1][_ent2] = hash[_type]--, {_type, e2})

	    if not params.oriented then
	       if _ent1>_ent2 then
		  local temp = _ent2
		  _ent2=_ent1
		  _ent1=temp
	       end
	       assert(_ent1<_ent2)
	       if relations[count][_ent1]==nil then relations[count][_ent1]={} end
	       relations[count][_ent1][_ent2] = hash[_type]--, {_type, e2})
	    else
	       if relations[count][_ent1]==nil then relations[count][_ent1]={} end
	       relations[count][_ent1][_ent2] = hash[_type]--, {_type, e2})
	       if _type=="isAssociatedWith" then --all relations are oriented exept isAssociatedWith
		  if relations[count][_ent2]==nil then relations[count][_ent2]={} end
		  relations[count][_ent2][_ent1] = hash[_type]
	       end
	    end
	    	    
	    --if relations[count][ent2]==nil then relations[count][ent2]={} end
	    --relations[count][ent2][ent1] = hash[_type]--, {_type, e2})
	    --table.insert(rel, {ent1, ent2})
	 end
      end

      filename = handle:read()
   end

   local back_hierarchy_rel = {}
   back_hierarchy_rel["treats"] = "isAssociatedWith"
   back_hierarchy_rel["influences"] = "isAssociatedWith"
   back_hierarchy_rel["decreases"] = "influences"
   back_hierarchy_rel["increases"] = "influences"
   back_hierarchy_rel["causes"] = "influences"
   back_hierarchy_rel["isAssociatedWith"] = nil
   back_hierarchy_rel["isEquivalentTo"] = nil
   
   local target = torch.Tensor(#hash)
   relations.isrelated = function(self, nsent, e1, e2, test)
      if not params.oriented then
	 assert(e1<e2)
      end
      --print("=================")
      --print(self[nsent])
      --print(nsent)
      --print(e1)
      --print(e2)
      if (not test) and params.trainhierarchy then
	 target:fill(0)
	 if self[nsent][e1] and self[nsent][e1][e2] and params.onlylabel[ hash[self[nsent][e1][e2]] ] then
	    local i=1
	    local current = hash[self[nsent][e1][e2]]
	    while current do
	       --print(current)
	       if params.softmargin or params.bcecriterion then
	       	  target[ hash[current] ] = 1
	       else
		  target[i] = hash[current]
	       end
	       current = back_hierarchy_rel[current]
	       i = i + 1
	    end
	 else
	    target[1] = hash["null"]
	 end
	 return target
      else
	 if self[nsent][e1] and self[nsent][e1][e2] and params.onlylabel[ hash[self[nsent][e1][e2]] ] then
	    return self[nsent][e1][e2]
	 else
	    return hash["null"]
	 end
      end
   end

   return relations
end

local wordhash, entityhash, deptypehash, poshash, relationhash, entityhash2

function loadhash(params)

   local path = "data/"
   
   wordhash = wordhash or _loadhash('data/hash/word.txt', params.nword)
   entityhash = entityhash or _loadhash('data/hash/entities.txt')
   relationhash = relationhash or _loadhash("data/hash/relations.txt")
   if params.notype then
      for i=3,#relationhash do
	 if relationhash[i]~="isEquivalentTo" then
	    relationhash[ relationhash[i] ] = 2
	 end
      end
   end
   if params.pgxtype then
      for i=3,#relationhash do
	 if relationhash[i]=="isEquivalentTo" or relationhash[i]=="treats" then
	    relationhash[ relationhash[i] ] = relationhash["null"]
	 else
	    relationhash[ relationhash[i] ] = relationhash["isAssociatedWith"]
	 end
      end
      print(relationhash)
   end
   entityhash2 = {"PADDING", "O", "Entity1", "Entity2", PADDING=1, O=2, Entity1=3, Entity2=4} --for entity position
   
end

function createdata(params, decodeonly)
   decodeonly = decodeonly or false
   
   local pathdata = params.data
   
   local words = loadwords(pathdata, wordhash, params.addraw, wordfeature, params.maxload)
   pad(words, 0, wordhash.PADDING)
   
   local starts, ends = loadstartend(pathdata, nil, params.maxload)

   local names = loadnames(pathdata, params.maxload)
   --print(names)
   
   local entities = loadentities(pathdata, ".ann",  params, entityhash)
   load_entity_indices(entities, words, starts, ends, wordhash, names)

   loaddag(entities)

   local relations = loadrelations(pathdata, ".ann", params.maxload, relationhash, params, entities)
   
   -- local idx
   -- for i=1,#names do
   --    if names[i]=="14702153_5" then
   -- 	 idx = i
   --    end
   -- end

   -- printw(words[idx], wordhash)
   -- print(entities[idx])
   -- print(relations[idx])
   
   -- io.read()

   local get_relative_distance
   if params.rdfsz~=0 then
      do 
	 local reldists = {torch.Tensor(), torch.Tensor()}
	 function get_relative_distance(ent, nent)
	    reldists[nent]:resizeAs(ent):fill(0)
	    local pattern = ent:eq(nent+2)
	    local pos = {}
	    for i=1,pattern:size(1) do if pattern[i]==1 then table.insert(pos, i) end
	    end
	    --print(pattern)
	    --print(pos)
	    --local _, currentent = ent:eq(nent+2):max(1) --+2 for padding and null
	    --currentent = currentent[1]
	    --print(ent)
	    --print(currentent)
	    for i=1,reldists[nent]:size(1) do
	       local min = math.huge
	       for j=1,#pos do if pos[j]<min then min = math.abs(pos[j]-i) end
	       end
	       reldists[nent][i] = min+1
	       --reldists[nent][i]=math.abs(currentent-i)+1
	    end
	    --print(reldists[nent])
	    --io.read()
	    return reldists[nent]
	 end
      end
      -- local en = torch.Tensor({2,2,2,2,2,3,2,3,2,2,2,4,2})
      -- print(get_relative_distance(en, 1):reshape(1,en:size(1)))
      -- print(get_relative_distance(en, 2):reshape(1,en:size(1)))
      -- print(en:reshape(1,en:size(1)))
      --exit()
   end

   
   return {names=names, wordhash=wordhash, entityhash=entityhash, entityhash2=entityhash2, relationhash=relationhash, words=words, entities=entities, relations=relations, size=#words.idx, get_relative_distance=get_relative_distance}
   
end


function get_trees(data, params)
   if params.arch=="treelstm" then

      treelstm = {}
      include("./treeLSTM/util/Tree.lua")
      include('./treeLSTM/layers/CRowAddTable.lua')
      include('./treeLSTM/models/LSTM.lua')
      include('./treeLSTM/models/TreeLSTM.lua')
      include('./treeLSTM/models/ChildSumTreeLSTM.lua')
      
      if params.anonymize then
	 if not paths.filep("data/PGxCorpus/trees_anon.input.McClosky.trees.ddg_tree_comp_reps") then
	    local f = io.open("data/PGxCorpus/trees_anon.input", "w")
	    if true then
	       for i=1,#data.words.idx do
		  for j=1,#data.entities[i] do
		     for k=j+1,#data.entities[i] do
			if is_included(data.entities[i][j][1], data.entities[i][k][1])
			   or is_included(data.entities[i][k][1], data.entities[i][j][1])
			   or overlapp(data.entities[i][j][5], data.entities[i][k][5])
			then
			   
			else
			   -- print("========================================================== " .. j .. " " .. k)
			   -- print(data.words[i])
			   -- print(data.words.sent[i])
			   local toto = anonymize(data.words[i], data.entities[i], j, k, data, params)
			   --printw(toto[1], data.wordhash)
			   for w=1,toto[1]:size(1) do
			      f:write(data.wordhash[toto[1][w]] .. " ")
			   end
			   f:write("\n")
			   --io.read()
			end
		     end
		  end
	       end
	       f:close()
	    end
	    
	    --parse file if not parsed
	    --https://github.com/BLLIP/bllip-parser
	    print("please parse the file \"data/PGxCorpus/trees_anon.input\" and provide a CONLL formated file")
	    print("the run the extractTrees.lua scrip on it to generate de trees")
	    io.read()
	 end

	 --load parse trees
	 local trees = loadtrees("data/PGxCorpus/trees_anon.input.McClosky.trees.ddg_tree_comp_reps")
	 trees2 = tree2tree(trees)
	 print(trees2[1])
	 
	 local trees = {}
	 local idx = 0
	 for i=1,#data.words.idx do
	    trees[i] = {}
	    for j=1,#data.entities[i] do
	       if not trees[i][j] then trees[i][j] = {} end
	       for k=j+1,#data.entities[i] do
		  if not trees[i][k] then trees[i][k] = {} end
		  if is_included(data.entities[i][j][1], data.entities[i][k][1])
		     or is_included(data.entities[i][k][1], data.entities[i][j][1])
		     or overlapp(data.entities[i][j][5], data.entities[i][k][5])
		  then
		     
		  else
		     if i==1 then print("tree " .. i .. " " .. j .. " " .. k) end
		     idx = idx + 1
		     trees[i][j][k] = trees2[idx]
		     trees[i][k][j] = trees2[idx] --the parse tree is the same in both directions
		  end
	       end
	    end
	 end
	 data.trees = trees
	 
	 function data.trees.gettrees(data, nsent, e1, e2)
	    if false then
	       print("==============================================================================")
	       print(nsent)
	       print(e1)
	       print(e2)
	       print(#data.trees[nsent])
	       print(#data.trees[nsent][e1])
	       print(data.trees[nsent][e1][e2])
	    end
	    return data.trees[nsent][e1][e2]
	 end
	 
      else
	 local f = io.open("data/PGxCorpus/trees.input", "w")
	 for i=1,#data.words.idx do
	    f:write(data.words.sent[i] .. "\n")
	 end
	 f:close()
      end
   end
end

function extract_data(data, percentage, sector, remove)
   
   remove = remove or false
   print("Extracting data. Remove=" .. (remove and "true" or "false"))
   local size = data.size

   local subsize = math.floor((size*percentage)/100)

   local start = (subsize * (sector-1))+1

   print("\tsize: " .. size .. " subcorpus size: " .. subsize .. " subcorpus start at " .. start)

   local tabs = {words=true, pos=true}

   local new_size_expected = size - subsize
   
   local newdata = {}
   for k,v in pairs(tabs) do
      if data[k] then
	 local newtab = {}
	 for i=1,subsize do
	    table.insert(newtab, data[k].idx[remove and start or (start+i-1)])
	    if remove then table.remove(data[k].idx, start) end
	    --if remove then table.remove(data[k].sent, start) end
	 end
	 local newtabsent = {}
	 if k=="words" then
	    for i=1,subsize do
	       table.insert(newtabsent, data[k].sent[remove and start or (start+i-1)])
	       if remove then table.remove(data[k].sent, start) end
	       --table.remove(data[k].sent, start)
	    end
	 end

	 
	 newdata[k] = {idx=newtab, sent=newtabsent}
	 setmetatable(newdata[k], getmetatable(data[k]))
      end
   end

   local tabs = {entities=true,relations=true,ids=true, names=true, trees=true}
   --local tabs = {words=true}
   
   -- if false then
   --    print("data")
   --    for i=1, 85 do
   -- 	 io.write(#data.entities[i] .. " ")
   --    end
   --    io.write("\n")
   -- end

   for k,v in pairs(tabs) do
      if data[k] then
	 local newtab = {}
	 for i=1,subsize do
	    table.insert(newtab, data[k][remove and start or (start+i-1)])
	    if remove then table.remove(data[k], start) end
	 end
	 newdata[k] = newtab
      end
   end
   
   newdata.entities.nent = data.entities.nent
   newdata.entities.typeent = data.entities.typeent
   newdata.entities.getent = data.entities.getent
   newdata.entities.getenttags = data.entities.getenttags
   newdata.entities.getnestenttype = data.entities.getnestenttype
   if data.trees then newdata.trees.gettrees = data.trees.gettrees end
   
   newdata.relations.isrelated = data.relations.isrelated
   
   data.size = #data.words.idx
   newdata.size = #newdata.words.idx

   if remove then assert(data.size==new_size_expected, size .. " " .. data.size .. " " .. new_size_expected) end
   if remove then assert(newdata.size==subsize) end
   
   --print("====")
   for k,v in pairs(data) do
      if not newdata[k] then newdata[k] = data[k] end
   end
   
   -- if false then
   --    print("newdata")
   --    for i=1, 35 do
   -- 	 io.write("  ")
   --    end
   --    io.write(" ")
   --    for i=1, 35 do
   -- 	 io.write(#newdata.entities[i] .. " ")
   --    end
   --    io.write("\n")
   
   --    print("olddata")
   --    for i=1, 35 do
   -- 	 io.write(#data.entities[i] .. " ")
   --    end
   --    for i=1, 35 do
   -- 	 io.write("  ")
   --    end
   
   --    for i=36, 50 do
   -- 	 io.write(#data.entities[i] .. " ")
   --    end
   --    io.write("\n")
   -- end

   return newdata
   
end
