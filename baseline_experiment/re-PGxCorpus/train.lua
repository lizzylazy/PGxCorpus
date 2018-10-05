require('data')
require('torch')
require('nn')
require('rnn')
require('network')
require('test')
require("trepl")

function printw(t, dict)
   print(t:size(1))
   for i=1,t:size(1) do
      io.write(dict[t[i]] .. " ")
   end
   io.write("\n")
end

function printinput(t, dict, ent)
   for i=1,t:size(1) do
      local w = dict[t[i]]
      if ent[i]~=2 then w = w:upper() end
      io.write(w .. " ")
   end
   io.write("\n")
end

cmd = torch.CmdLine()

cmd:text()
cmd:text('Chunk-based phrase prediction')
cmd:text()
cmd:text()
cmd:text('Misc options:')
cmd:option('-data', 'data/PGxCorpus', 'data directory')
cmd:option('-validp', 10, 'training corpus proportion for the validation')
cmd:option('-valids', 1, 'sector extracted from training for the validation')
cmd:option('-wfsz', 100, 'word feature size')
cmd:option('-efsz', 10, 'entity feature size (for the 2 candidate entities)')
cmd:option('-tfsz', 0, 'entity tag features size')
cmd:option('-pfsz', 0, 'pos tag features size')
cmd:option('-rdfsz', 0, 'relative distance features size')
cmd:option('-wsz', 1, 'window size')
cmd:option('-wsz2', 1, 'window size for rnn-cnn')
cmd:option("-nword", 20000, "dictionary size")
cmd:option("-nhu", '{200}', "hidden units")
cmd:option('-seed', 1111, 'seed')
cmd:option('-lr', 0.001, 'learning rate')
cmd:option('-lm', false, 'use language model')
cmd:option('-norm', false, 'normalise lm')
cmd:option('-log', false, "log file")
cmd:option('-restart', '', 'model to restart from')
cmd:option('-dir', '.', 'subdirectory to save the stuff')
cmd:option('-dropout', 0, 'add dropout')
cmd:option('-dp', 0, 'dropout position 1:features / 2:gru / 4:scorer / 3:all')
cmd:option('-maxload', math.huge, 'data to load')
cmd:option('-maxsize', math.huge, 'sentencesizemax')
cmd:option('-notest', false, 'do not test')
cmd:option('-debug', false, 'debug option for nngraph')
cmd:option('-mobius', false, 'run on mobius')
cmd:option('-corpus', '{full}', 'corpus to use')
cmd:option('-parser', 'stanford', 'parser to use (stanford or McClosky)')
cmd:option('-nosgd', false, 'no sgd')
cmd:option('-time', false, 'time evaluation')
cmd:option('-anon', false, 'anonymize drugs')
cmd:option('-debug2', false, 'debug2')
cmd:option('-maxent', 1000, 'max entities in training sentence')
cmd:option('-restartparams', '{}', 'max entities in training sentence')
cmd:option('-niter', 100, 'max iter')
cmd:option('-crossbalance', 0, 'cross corpus balance')
cmd:option('-wszs', '{3,3,5,5}', 'corpus to test on')
cmd:option('-channels', 1, '')
cmd:option('-1r', 0, 'use only 1 specified relation for the additional corpus') --only for 1 additional corpus
cmd:option('-select_data', '{}', 'fusion relations for the additional corpus')
cmd:text()

local params = cmd:parse(arg)

torch.setdefaulttensortype('torch.FloatTensor')

torch.setnumthreads(1)

if true then
   torch.manualSeed(params.seed)
else
   torch.manualSeed(os.time())
end


--params.select_data = params.select_data:gsub("{", "{\"")
--params.select_data = params.select_data:gsub("}", "\"}")
params.select_data = params.select_data:gsub(" +", "")
--params.select_data = params.select_data:gsub(",", "\",\"")

params.nhu = loadstring("return " .. params.nhu)()
--print(params.select_data)
params.select_data = loadstring("return " .. params.select_data)()
--print(params.select_data)
--exit()

params.wszs = loadstring("return " .. params.wszs)()  
local restartparams = loadstring("return " .. params.restartparams)()



local frestart
local rundir
local expidx = 0
if params.restart ~= '' then
   print(string.format('restarting from <%s>', params.restart))
   frestart = torch.DiskFile(params.restart):binary()
   local restart = params.restart
   params = frestart:readObject()
   params.restart = restart
   rundir = params.rundir
   for i=0,99 do
      expidx = i
      local fname = string.format('%s/log-%.2d', rundir, expidx)
      local f = io.open(fname)
      if f then
         print(string.format('<%s> found', fname))
         f:close()
      else
         break
      end
   end
   if not params.pfsz then params.pfsz=0 end
   if not params.tfsz then params.tfsz=0 end
   if not params.rdfsz then params.rdfsz=0 end

   for k,v in pairs(restartparams) do
      params[k] = v
   end
else
   rundir = cmd:string('exp', params, {dir=true, nhu=true, select_data=true, restartparams=true, wszs=true})
   rundir = rundir .. ",nhu={" .. params.nhu[1]
   for i=2,#params.nhu do
      rundir = rundir .. "-" .. params.nhu[i]
   end
   rundir = rundir .. "}"
   rundir = rundir .. ",wszs={" .. params.wszs[1]
   for i=2,#params.wszs do
      rundir = rundir .. "-" .. params.wszs[i]
   end
   rundir = rundir .. "}"
   --print(params.select_data)
   if #params.select_data~=0 then
      local toto = params.select_data["full"]:match("_([^_]+)$")
      rundir = rundir .. ",select={" .. toto 
      rundir = rundir .. "}"
      rundir = rundir .. "}"
   end
   if params.dir ~= '.' then
      rundir = params.dir .. '/' .. rundir
   end
   params.rundir = rundir
   print(params.rundir)
   os.execute('mkdir -p ' .. rundir)
   params.currentiter = 0
end
if params.restart=='' and params.log then
   cmd:log(string.format('%s/log-%.2d', rundir, expidx), params)
end

   
print("restart with : ")
print("/home/joel/torch/install/bin/luajit /home/joel/Bureau/loria/code/semeval2013DDI/train.lua -restart " .. string.format('%s/model.bin', rundir))

loadhash(params)

local data = createdata(params, params.corpus, "train")

-- for i=1,data.size do
--    print("====================================== " .. i)
--    print(data.entities[i])
--    io.read()
-- end

params.nword = math.min(params.nword, #data.wordhash)

local vdata, tdata
if not params.notest then
   local vdata = extract_data(data, params.validp, params.valids, true)
   local tdata = extract_data(data, params.validp, params.valids, true)
end
local subtraindata = extract_data(data, params.validp, params.valids, false)


--dataidx contains all the sample to be forwarded (sentence indices and couple of entities)
local dataidx = {}
for j=1,data.size do
   local n = data.entities.nent(data,j)
   local nrel = ((n * (n-1))/2)
   for k=1, nrel do
      table.insert(dataidx,{j,k})
   end
end

print("creating network")
local network = createnetworks(params,data)

if frestart then
   print('reloading network')
   if params.restart:match("model_net") then
      print("net")
      network = frestart:readObject()
   else
      print("weight")
      net = frestart:readObject()
      network:loadnet(params, net)
   end
   print("now testing")
   local macro_p,macro_r,macro_f1,c,micro_p,micro_r,micro_f1 = test(network, vdata, params)
   print("Valid_macro: " .. macro_p .. " " .. macro_r .. " " .. macro_f1)
   print("Valid_micro: " .. micro_p .. " " .. micro_r .. " " .. micro_f1)
   
   local macro_p,macro_r,macro_f1,c,micro_p,micro_r,micro_f1 = test(network, tdata, params)
   print("Test_macro: " .. macro_p .. " " .. macro_r .. " " .. macro_f1)
   print("Test_micro: " .. micro_p .. " " .. micro_r .. " " .. micro_f1)
      --exit()
   -- print(p)
   -- print(r)
   -- print(f1)
   -- exit()
end
--print(network.lookup)
--print(network.lookup2)

local networksave = network:getnetsave(params)

local criterion = nn.ClassNLLCriterion()

params.best = params.best or 0

--local nf = 0

print("now training")
local cost = 0
local ntoolong, nnoent, nforward, nsent = 0, 0, 0, 0

local fwddatas = torch.Tensor(#data):fill(0)

local inputwords = torch.Tensor()
local inputentities = torch.Tensor()
local gradinput = torch.Tensor()
local targets = torch.Tensor()

local currentmax = 0

local iter = 0

while true do
   iter = iter + 1
   if iter>params.niter then exit() end
   if params.debug2 then print("---------------------------------------Training--------------------------------------------------") end
   
   local timer2
   local timeforward, timebackward, timegetgraph = 0, 0, 0
   if params.time then timer2 = torch.Timer() end
   local timer = torch.Timer()
   timer:reset()

   network:training()
   
   if params.dropout~=0 then
      --if type(network.dropout)~="table" then error("check that") end
      if params.dp==1 or params.dp==3 or params.dp==4 then
       	 network.dropout:training()
      end
   end

   local perm = torch.randperm(#dataidx)
   
   local nex = 0
   for i=1, perm:size(1) do
      nforward = nforward + 1
      local idx = params.nosgd and dataidx[i][1] or dataidx[ perm[i] ][1] 
      local ent_pair_idx = params.nosgd and dataidx[i][2] or dataidx[ perm[i] ][2]
      
      --print(" sentence " .. idx .. " size " .. " nb entities " .. data.entities.nent(data, idx) .. " entity couple " .. ent_pair_idx)
      --printw(datas[datacorpus].words[idx], datas[datacorpus].wordhash)
      
      --collectgarbage()
      if i%500==0 then
	 print(i .. " / " .. perm:size(1) .. "(" .. string.format('%.2f', nforward/timer:time().real) .. " ex/s)")
	 collectgarbage()
      end

      local words = data.words[idx]

      local n_ent_pair = 0
      for ent1=1,data.entities.nent(data, idx) do
	 for ent2=ent1+1,data.entities.nent(data, idx) do
	    --nf = nf +1
	    --print(nf)
	    --printw(words, datas[1].wordhash)
	    --print(data.relations[idx])
	    
	    n_ent_pair = n_ent_pair + 1
	    
	    if n_ent_pair~=ent_pair_idx then
	       --this is not the pair of entities considered (see dataidx[ perm[i] ])
	       --print("do not forward relation between " .. ent1 .. " and " .. ent2 .. " " .. idx) else print("do forward")
	    else
	       --print(_select(params, data, idx,ent1,ent2))
	       if is_included(data.entities[idx][ent1][1], data.entities[idx][ent2][1]) or is_included(data.entities[idx][ent2][1], data.entities[idx][ent1][1]) then
		  --These entities are nested and thus not related
		  -- print(data.entities[idx][ent1])
		  -- print(data.entities[idx][ent2])
		  -- exit()
	       else
		  --print(ent1, ent2)
		  --print(nf .. " sentence " .. idx .. " relation between " .. ent1 .. " and " .. ent2 .. " (" .. data.relations:isrelated(idx, ent1, ent2) .. ")")
		  local entities = data.entities.getent(data, idx, ent1, ent2)
		  if (params.dp==2 or params.dp==3 or params.rnn=="lstm" or params.rnn=="cnn")  then entities = entities:view(1, entities:size(1)) end
		  
		  local input = {words}
		  
		  if params.tfsz~=0 then table.insert(input, data.entities.getenttags(data, idx, ent1, ent2)) end
		  if params.pfsz~=0 then table.insert(input, data.pos[idx]) end
		  if params.rdfsz~=0 then
		     table.insert(input, data.get_relative_distance(entities, 1))
		     table.insert(input, data.get_relative_distance(entities, 2))
		  end
		  table.insert(input, entities)
		  
		  --debug
		  if params.debug then
		     nngraph.setDebug(true)
		     network.g.name = 'my_bad_linear_net'
		     pcall(function() network:forward(input) end)
		     os.execute('echo my_bad_linear_net.svg')
		  end
		  
		  if params.time then timer2:reset() end
		  
		  local output
		  output = network:forward(input, data.corpus)
		  if params.time then timeforward = timeforward + timer2:time().real end
		  
		  local target = data.relations:isrelated(idx, ent1, ent2)
		  --printw(input[1], data.wordhash)
		  --print(data.entities[idx])
		  --print(data.relations[idx])
		  --print(target)
		  --io.read()
		  
		  --print(network.network:get(2).output:sum())
		  if params.debug2 then printinput(words, data.wordhash, input[2], data.wordhash) end
		  
		  if params.debug2 then
		     local max, indice = output:max(1)--caution: comment this!!!!!!!!!!!!!!
		     print("old " .. target .. " " .. indice[1])
		     for i=1,output:size(1) do io.write(output[i] .. " ") end; io.write("\n")
		  end
		  
		  cost = cost + criterion:forward(output, target)
		  local grad = criterion:backward(output, target)
		  
		  		  network:zeroGradParameters()
		  if params.time then timer2:reset() end
		  network:backwardUpdate(input, data.corpus, grad, params.lr)
		  if params.time then timebackward = timebackward + timer2:time().real end

		  
		  if params.debug2 then
		     local max, indice = output:max(1)--caution: comment this!!!!!!!!!!!!!!
		     print("new " .. target .. " " .. indice[1])
		     for i=1,output:size(1) do io.write(output[i] .. " ") end; io.write("\n") 
		  end
	       end
	    end
	    --io.read()
	 end
      end
      ::continue::
      
   end

   -- print(datas[1].relationhash)
   -- print(relation_pos)

   -- local total = 0
   -- for k,v in pairs(relation_pos) do
   --    total = total + v
   -- end
   -- print(total)
   -- exit()
   
   -- print(fwddatas)
   
   local file = io.open(rundir .. "/cost", 'a')
   print("cost " .. cost/nforward)
   local t = timer:time().real
   print(string.format('# ex/s = %.2f [%d ex over %d processed -- %.4g%%] %.2f s', nforward/t, nex, perm:size(1), nex/perm:size(1)*100, t))
   file:write(cost/nforward .. "\n")
   file:close()
   cost = 0
   --io.read()
   
   print(nsent .. " / " .. perm:size(1) .. " samples forwarded (" .. nforward .. " possible relations)")
   print(ntoolong .. " long sentences skipped")
   print(nnoent .. " sentences with less than 2 entities")

   ntoolong, nnoent, nforward, nsent = 0, 0, 0, 0 


   if params.time then
      print("time forward : " .. timeforward)
      print("time backward : " .. timebackward)
      print("time getgraph : " .. timegetgraph)
      timeforward = 0
      timebackward = 0
      timegegraph = 0
      io.read()
   end

   print('saving: last model')
   local f = torch.DiskFile(string.format('%s/model.bin', rundir), 'w'):binary()
   f:writeObject(params)
   f:writeObject(networksave)
   f:close()

   -- local f = torch.DiskFile(string.format('%s/model_net.bin', rundir), 'w'):binary()
   -- f:writeObject(params)
   -- f:writeObject(network)
   -- f:close()   
   print("---------------------------------------Testing--------------------------------------------------")


   print("*****************************Test on train***********************************")
   --test on train
   local fcost = io.open(rundir .. "/cost_train", 'a')
   local f_macro_precision = io.open(rundir .. "/macro_precision_train", 'a')
   local f_macro_recall = io.open(rundir .. "/macro_recall_train", 'a')
   local f_macro_f1 = io.open(rundir .. "/macro_f1-score_train", 'a')
   local f_micro_precision = io.open(rundir .. "/micro_precision_train", 'a')
   local f_micro_recall = io.open(rundir .. "/micro_recall_train", 'a')
   local f_micro_f1 = io.open(rundir .. "/micro_f1-score_train", 'a')
   
   local macro_p,macro_r,macro_f1,c,micro_p,micro_r,micro_f1 = test(network, subtraindata, params)
   print("Train_macro: " .. macro_p .. " " .. macro_r .. " " .. macro_f1)
   print("Train_micro: " .. micro_p .. " " .. micro_r .. " " .. micro_f1)
   
   f_macro_precision:write(macro_p .. "\n"); f_macro_precision:flush()
   f_macro_recall:write(macro_r .. "\n"); f_macro_recall:flush()
   f_macro_f1:write(macro_f1 .. "\n"); f_macro_f1:flush()
   f_micro_precision:write(micro_p .. "\n"); f_micro_precision:flush()
   f_micro_recall:write(micro_r .. "\n"); f_micro_recall:flush()
   f_micro_f1:write(micro_f1 .. "\n"); f_micro_f1:flush()
   fcost:write(c .. "\n"); fcost:flush()
   
   fcost:close()
   f_macro_precision:close(); f_macro_recall:close(); f_macro_f1:close()
   f_micro_precision:close(); f_micro_recall:close(); f_micro_f1:close()
   f1 = macro_f1
   
   if not params.notest then
      
      print("============================================================================")
      print("================================now testing=================================")
      print("============================================================================")


      	 --test on valid (youpi!)
      local f1
      print("*****************************Test on valid***********************************")
      local fcost = io.open(rundir .. "/cost_valid", 'a')
      local f_macro_precision = io.open(rundir .. "/macro_precision_valid", 'a')
      local f_macro_recall = io.open(rundir .. "/macro_recall_valid", 'a')
      local f_macro_f1 = io.open(rundir .. "/macro_f1-score_valid", 'a')
      local f_micro_precision = io.open(rundir .. "/micro_precision_valid", 'a')
      local f_micro_recall = io.open(rundir .. "/micro_recall_valid", 'a')
      local f_micro_f1 = io.open(rundir .. "/micro_f1-score_valid", 'a')
      
      local macro_p,macro_r,macro_f1,c,micro_p,micro_r,micro_f1 = test(network, vdata, params)
      print("Valid_macro: " .. macro_p .. " " .. macro_r .. " " .. macro_f1)
      print("Valid_micro: " .. micro_p .. " " .. micro_r .. " " .. micro_f1)
      
      f_macro_precision:write(macro_p .. "\n"); f_macro_precision:flush()
      f_macro_recall:write(macro_r .. "\n"); f_macro_recall:flush()
      f_macro_f1:write(macro_f1 .. "\n"); f_macro_f1:flush()
      f_micro_precision:write(micro_p .. "\n"); f_micro_precision:flush()
      f_micro_recall:write(micro_r .. "\n"); f_micro_recall:flush()
      f_micro_f1:write(micro_f1 .. "\n"); f_micro_f1:flush()
      fcost:write(c .. "\n"); fcost:flush()
      
      fcost:close()
      f_macro_precision:close(); f_macro_recall:close(); f_macro_f1:close()
      f_micro_precision:close(); f_micro_recall:close(); f_micro_f1:close()
      f1 = macro_f1

      if f1 > params.best then
	 params.best = f1
	 print('saving test: better than ever ' .. f1)
	 local f = torch.DiskFile(string.format('%s/model-best-valid.bin', rundir), 'w'):binary()
	 f:writeObject(params)
	 f:writeObject(networksave)
	 f:close()
      end

      
      --test on test (bouhou!)
      print("*****************************Test on test***********************************")
      local fcost = io.open(rundir .. "/cost_test", 'a')
      local f_macro_precision = io.open(rundir .. "/macro_precision_test", 'a')
      local f_macro_recall = io.open(rundir .. "/macro_recall_test", 'a')
      local f_macro_f1 = io.open(rundir .. "/macro_f1-score_test", 'a')
      local f_micro_precision = io.open(rundir .. "/micro_precision_test", 'a')
      local f_micro_recall = io.open(rundir .. "/micro_recall_test", 'a')
      local f_micro_f1 = io.open(rundir .. "/micro_f1-score_test", 'a')
      
      local macro_p,macro_r,macro_f1,c,micro_p,micro_r,micro_f1 = test(network, tdata, params)
      print("Test_macro: " .. macro_p .. " " .. macro_r .. " " .. macro_f1)
      print("Test_micro: " .. micro_p .. " " .. micro_r .. " " .. micro_f1)
      
      f_macro_precision:write(macro_p .. "\n"); f_macro_precision:flush()
      f_macro_recall:write(macro_r .. "\n"); f_macro_recall:flush()
      f_macro_f1:write(macro_f1 .. "\n"); f_macro_f1:flush()
      f_micro_precision:write(micro_p .. "\n"); f_micro_precision:flush()
      f_micro_recall:write(micro_r .. "\n"); f_micro_recall:flush()
      f_micro_f1:write(micro_f1 .. "\n"); f_micro_f1:flush()
      fcost:write(c .. "\n"); fcost:flush()
      
      fcost:close()
      f_macro_precision:close(); f_macro_recall:close(); f_macro_f1:close()
      f_micro_precision:close(); f_micro_recall:close(); f_micro_f1:close()
      
   else
      for i=1,#datas do
	 if params.testc==0 or params.testc==i then
	    local macro_p,macro_r,macro_f1,c,micro_p,micro_r,micro_f1 = test(network, data, params)
	    print("Train_macro: " .. macro_p .. " " .. macro_r .. " " .. macro_f1)
	    print("Train_micro: " .. micro_p .. " " .. micro_r .. " " .. micro_f1)
	 end
      end
   end
end