-- [yue]: apng.yue
local _module_0 = { } -- 1
local struct = require('lib.struct') -- 1
if type(bit) ~= 'table' then -- 2
	_G.bit = require('lib.bitop') -- 2
end -- 2
local crc32 = require('lib.crc32').hash -- 3
local read -- 6
read = function(data) -- 6
	local read_ -- 7
	read_ = function(n, pack) -- 7
		if pack == nil then -- 7
			pack = nil -- 7
		end -- 7
		local res -- 8
		res, data = data:sub(1, n), data:sub(n + 1, -1) -- 8
		if pack then -- 9
			return struct.unpack('>' .. pack, res) -- 9
		else -- 9
			return res -- 9
		end -- 9
	end -- 7
	local read_chunk -- 10
	read_chunk = function() -- 10
		local size, id = read_(8, 'Ic4') -- 11
		-- pp id, size
		if 'IHDR' == id then -- 14
			local w, h, depth, colortype, compresstype, filter, interlace, crc = read_(size + 4, 'IIBBBBBI') -- 15
			-- pp w, h, depth, colortype, compresstype, filter, interlace, crc
			return { -- 17
				id = id, -- 17
				size = size, -- 17
				width = w, -- 17
				height = h, -- 17
				depth = depth, -- 17
				colortype = colortype, -- 17
				compresstype = compresstype, -- 17
				filter = filter, -- 17
				interlace = interlace, -- 17
				crc = crc -- 17
			} -- 17
		elseif 'acTL' == id then -- 18
			local frames, plays = read_(8, 'II') -- 19
			-- pp frames, plays
			return { -- 21
				id = id, -- 21
				size = size, -- 21
				frames = frames, -- 21
				plays = plays, -- 21
				crc = read_(4, 'I') -- 21
			} -- 21
		elseif 'fcTL' == id then -- 22
			local n, w, h, l, t, delay1, delay2, dispose, blend = read_(26, 'IIIIIHHBB') -- 23
			-- pp n, w, h, l, t, delay1/delay2, dispose, blend
			return { -- 25
				id = id, -- 25
				size = size, -- 25
				num = n, -- 25
				width = w, -- 25
				height = h, -- 25
				left = l, -- 25
				top = t, -- 25
				delay1 = delay1, -- 25
				delay2 = (delay2 == 0 and 100 or delay2), -- 25
				dispose = dispose, -- 25
				blend = blend, -- 25
				crc = read_(4, 'I') -- 25
			} -- 25
		elseif 'fdAT' == id then -- 26
			local n = read_(4, 'I') -- 27
			return { -- 28
				id = id, -- 28
				size = size, -- 28
				num = n, -- 28
				data = read_(size - 4), -- 28
				crc = read_(4, 'I') -- 28
			} -- 28
		else -- 31
			return { -- 31
				id = id, -- 31
				size = size, -- 31
				data = read_(size), -- 31
				crc = read_(4, 'I') -- 31
			} -- 31
		end -- 31
	end -- 10
	local sig = read_(8) -- 32
	local _, _, width, height = struct.unpack('>Ic4II', data) -- 33
	-- pp width, height
	assert(sig == '\137PNG\13\10\26\10') -- 35
	local chunks = { } -- 36
	while #data >= 12 do -- 37
		chunks[#chunks + 1] = read_chunk() -- 38
	end -- 38
	return { -- 39
		signature = sig, -- 39
		width = width, -- 39
		height = height, -- 39
		chunks = chunks -- 39
	} -- 39
end -- 6
local tochunk -- 41
tochunk = function(id, data) -- 41
	return struct.pack('>Ic4', #data, id) .. data .. struct.pack('>I', crc32(id .. data)) -- 41
end -- 41
local read1frame -- 43
read1frame = function(frame) -- 43
	local data = '\137PNG\13\10\26\10' .. tochunk('IHDR', struct.pack('>IIBBBBB', frame.width, frame.height, frame.ihdr.depth, frame.ihdr.colortype, frame.ihdr.compresstype, frame.ihdr.filter, frame.ihdr.interlace)) .. (frame.pltechunk or '') .. (frame.trnschunk or '') .. tochunk('IDAT', frame.data) .. frame.iendchunk -- 44
	return gr.newImage(love.filesystem.newFileData(data, '1.png')) -- 49
end -- 43
local APNG -- 52
local _class_0 -- 52
local _base_0 = { -- 52
	update1frame = function(self, frame) -- 70
		frame.img = frame.img or read1frame(frame) -- 71
		gr.setCanvas(self.canvas) -- 72
		if self._dispose then -- 73
			self:_dispose() -- 73
		end -- 73
		do -- 74
			local _exp_0 = frame.dispose -- 74
			if 0 == _exp_0 then -- 75
				self._dispose = nil -- 75
			elseif 1 == _exp_0 then -- 76
				self._dispose = function() -- 76
					gr.setScissor(frame.left, frame.top, frame.width, frame.height) -- 77
					gr.clear(self.clearcolor) -- 78
					return gr.setScissor() -- 79
				end -- 76
			elseif 2 == _exp_0 then -- 80
				self._dispose = nil -- 80
			end -- 80
		end -- 80
		do -- 81
			local _exp_0 = frame.blend -- 81
			if 0 == _exp_0 then -- 82
				gr.setScissor(frame.left, frame.top, frame.width, frame.height) -- 83
				gr.clear(self.clearcolor) -- 84
				gr.setScissor() -- 85
			end -- 85
		end -- 85
		gr.draw(gr.setColor(1, 1, 1) or frame.img, frame.left, frame.top) -- 87
		return gr.setCanvas() -- 88
	end, -- 90
	update = function(self, dt) -- 90
		self.clock = self.clock + dt -- 91
		while self.clock > self.frames[self.index].delay do -- 92
			self.clock = self.clock - self.frames[self.index].delay -- 93
			if self.index < #self.frames then -- 94
				self.index = self.index + 1 -- 94
			else -- 96
				self.plays = self.plays - 1 -- 96
				if self.plays == 0 then -- 97
					self.update = function(self) end -- 98
					return -- 99
				end -- 97
				self.index = 1 -- 100
			end -- 94
			self:update1frame(self.frames[self.index]) -- 101
		end -- 101
	end -- 52
} -- 52
if _base_0.__index == nil then -- 52
	_base_0.__index = _base_0 -- 52
end -- 101
_class_0 = setmetatable({ -- 52
	__init = function(self, filecontent) -- 53
		local tree = read(filecontent) -- 54
		local ihdr, pltechunk, trnschunk, fctl, iendchunk -- 55
		self.plays, self.frames, ihdr, pltechunk, trnschunk, fctl, iendchunk = math.huge, { }, nil, nil, nil, nil, tochunk('IEND', '') -- 55
		local _list_0 = tree.chunks -- 56
		for _index_0 = 1, #_list_0 do -- 56
			local chunk = _list_0[_index_0] -- 56
			local _exp_0 = chunk.id -- 57
			if 'IHDR' == _exp_0 then -- 58
				ihdr = chunk -- 58
			elseif 'PLTE' == _exp_0 then -- 59
				pltechunk = tochunk('PLTE', chunk.data) -- 59
			elseif 'tRNS' == _exp_0 then -- 60
				trnschunk = tochunk('tRNS', chunk.data) -- 60
			elseif 'acTL' == _exp_0 then -- 61
				self.plays = chunk.plays > 0 and chunk.plays or math.huge -- 61
			elseif 'fcTL' == _exp_0 then -- 62
				fctl = chunk -- 62
			elseif 'IDAT' == _exp_0 or 'fdAT' == _exp_0 then -- 63
				if fctl then -- 63
					local _obj_0 = self.frames -- 63
					_obj_0[#_obj_0 + 1] = { -- 63
						ihdr = ihdr, -- 63
						pltechunk = pltechunk, -- 63
						trnschunk = trnschunk, -- 63
						iendchunk = iendchunk, -- 63
						width = fctl.width, -- 63
						height = fctl.height, -- 63
						left = fctl.left, -- 63
						top = fctl.top, -- 63
						delay = fctl.delay1 / fctl.delay2, -- 63
						dispose = fctl.dispose, -- 63
						blend = fctl.blend, -- 63
						data = chunk.data -- 63
					} -- 63
				end -- 63
			end -- 63
		end -- 63
		self.canvas = gr.newCanvas(tree.width, tree.height) -- 64
		self.clearcolor = { -- 65
			0, -- 65
			0, -- 65
			0, -- 65
			0 -- 65
		} -- 65
		self.clock, self.index = 0, 1 -- 66
		return self:update1frame(self.frames[1]) -- 67
	end, -- 52
	__base = _base_0, -- 52
	__name = "APNG" -- 52
}, { -- 52
	__index = _base_0, -- 52
	__call = function(cls, ...) -- 52
		local _self_0 = setmetatable({ }, _base_0) -- 52
		cls.__init(_self_0, ...) -- 52
		return _self_0 -- 52
	end -- 52
}) -- 52
_base_0.__class = _class_0 -- 52
APNG = _class_0 -- 52
_module_0["APNG"] = APNG -- 52
return _module_0 -- 101
