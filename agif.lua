local _module_0 = { }
local struct = require('lib.struct')
local readAGif
readAGif = function(filecontent)
	local read
	read = function(n)
		local result
		result, filecontent = filecontent:sub(1, n), filecontent:sub(n + 1)
		return result
	end
	local read_block
	read_block = function()
		local _exp_0 = read(1)
		if '!' == _exp_0 then
			local _exp_1 = read(1):byte()
			if 0xf9 == _exp_1 then
				local _, flags, delay, transparent, _ = struct.unpack('<BBHBB', read(6))
				pp('graphiccontrol', flags, delay, transparent)
				return {
					id = 'graphiccontrol',
					flags = flags,
					delay = delay / 100,
					transparent = transparent
				}
			elseif 0xfe == _exp_1 then
				pp('comment')
				local size = read(1):byte()
				while size > 0 do
					local _
					_, size = read(size), read(1):byte()
				end
				return {
					id = 'commment'
				}
			elseif 0x01 == _exp_1 then
				pp('plain text')
				read(13)
				local size = read(1):byte()
				while size > 0 do
					local _
					_, size = read(size), read(1):byte()
				end
				return {
					id = 'plaintext'
				}
			elseif 0xff == _exp_1 then
				pp('application extension')
				read(12)
				local size = read(1):byte()
				while size > 0 do
					local _
					_, size = read(size), read(1):byte()
				end
				return {
					id = 'application'
				}
			end
		elseif ',' == _exp_0 then
			local left, top, width, height, flags = struct.unpack('<HHHHB', read(9))
			pp('imageblock', left, top, width, height, flags)
			local palette = flags > 127 and read(3 * 2 ^ (flags % 8 + 1)) or ''
			local minimumcodesize, size = read(1):byte(), read(1):byte()
			local blocks
			do
				local _accum_0 = { }
				local _len_0 = 1
				while size > 0 do
					local _with_0 = read(size)
					size = read(1):byte()
					_accum_0[_len_0] = _with_0
					_len_0 = _len_0 + 1
				end
				blocks = _accum_0
			end
			return {
				id = 'imageblock',
				left = left,
				top = top,
				width = width,
				height = height,
				flags = flags,
				palette = palette,
				minimumcodesize = minimumcodesize,
				blocks = blocks
			}
		elseif ';' == _exp_0 then
			return {
				id = 'terminator'
			}
		else
			return pp('block read error')
		end
	end
	local sig = read(6)
	assert(sig == 'GIF89a' or sig == 'GIF87a')
	local width, height, flags, bg, aspect = struct.unpack('<HHBBB', read(7))
	local palette = flags > 127 and read(3 * 2 ^ (flags % 8 + 1)) or ''
	pp(width, height, flags, #palette / 3)
	local blocks
	do
		local _accum_0 = { }
		local _len_0 = 1
		while #filecontent > 0 do
			_accum_0[_len_0] = read_block()
			_len_0 = _len_0 + 1
		end
		blocks = _accum_0
	end
	return width, height, flags, bg, aspect, palette, blocks
end
local _anon_func_0 = function(frame, string)
	local _accum_0 = { }
	local _len_0 = 1
	local _list_0 = frame.blocks
	for _index_0 = 1, #_list_0 do
		local b = _list_0[_index_0]
		_accum_0[_len_0] = string.char(#b) .. b
		_len_0 = _len_0 + 1
	end
	return _accum_0
end
local read1frame
read1frame = function(frame)
	local data = 'GIF89a' .. struct.pack('<HHBBB', frame.width, frame.height, frame.globalflags, frame.bg, frame.aspect) .. frame.globalpalette .. '!' .. struct.pack('<BBBHBB', 0xf9, 4, frame.graphiccontrol.flags, 0, frame.graphiccontrol.transparent, 0) .. ',' .. struct.pack('<HHHHB', 0, 0, frame.width, frame.height, frame.flags) .. frame.palette .. string.char(frame.minimumcodesize) .. table.concat(_anon_func_0(frame, string)) .. '\0' .. ';'
	return gr.newImage(love.data.newByteData(data))
end
local AGif
local _class_0
local _base_0 = {
	update1frame = function(self, frame)
		frame.image = frame.image or read1frame(frame)
		gr.setCanvas(self.canvas)
		do
			local _obj_0 = self._dispose
			if _obj_0 ~= nil then
				_obj_0()
			end
		end
		do
			local _exp_0 = frame.dispose
			if 0 == _exp_0 or 1 == _exp_0 then
				self._dispose = nil
			elseif 2 == _exp_0 then
				self._dispose = function()
					gr.setScissor(frame.left, frame.top, frame.width, frame.height)
					gr.clear(self.bgcolor)
					return gr.setScissor()
				end
			elseif 3 == _exp_0 then
				self._dispose = nil
			end
		end
		do
			local _exp_0 = frame.blend
			if 1 == _exp_0 then
				gr.setScissor(frame.left, frame.top, frame.width, frame.height)
				gr.clear(self.bgcolor)
				gr.setScissor()
			end
		end
		gr.draw(gr.setColor(1, 1, 1) or frame.image, frame.left, frame.top)
		return gr.setCanvas()
	end,
	update = function(self, dt)
		self.clock = self.clock + dt
		if self.clock > self.frames[self.index].graphiccontrol.delay then
			self.clock = self.clock - self.frames[self.index].graphiccontrol.delay
			if self.index < #self.frames then
				self.index = self.index + 1
			else
				self.plays = self.plays - 1
				if self.plays <= 0 then
					self.update = function(self) end
					return
				end
				self.index = 1
			end
			pp('index', self.index)
			return self:update1frame(self.frames[self.index])
		end
	end
}
if _base_0.__index == nil then
	_base_0.__index = _base_0
end
_class_0 = setmetatable({
	__init = function(self, filecontent)
		local width, height, flags, bg, aspect, palette, blocks = readAGif(filecontent)
		local graphiccontrol
		self.loops, self.bgcolor, self.frames, graphiccontrol = math.huge, {
			0,
			0,
			0,
			1
		}, { }, nil
		for _index_0 = 1, #blocks do
			local block = blocks[_index_0]
			local _exp_0 = block.id
			if 'graphiccontrol' == _exp_0 then
				graphiccontrol = block
			elseif 'imageblock' == _exp_0 then
				local _obj_0 = self.frames
				local _tab_0 = { }
				local _idx_0 = 1
				for _key_0, _value_0 in pairs(block) do
					if _idx_0 == _key_0 then
						_tab_0[#_tab_0 + 1] = _value_0
						_idx_0 = _idx_0 + 1
					else
						_tab_0[_key_0] = _value_0
					end
				end
				_tab_0.globalflags = flags
				_tab_0.bg = bg
				_tab_0.aspect = aspect
				_tab_0.globalpalette = palette
				_tab_0.graphiccontrol = graphiccontrol
				_obj_0[#_obj_0 + 1] = _tab_0
			end
		end
		self.canvas = gr.newCanvas(width, height)
		self.clock, self.index = 0, 1
		return self:update1frame(self.frames[1])
	end,
	__base = _base_0,
	__name = "AGif"
}, {
	__index = _base_0,
	__call = function(cls, ...)
		local _self_0 = setmetatable({ }, _base_0)
		cls.__init(_self_0, ...)
		return _self_0
	end
})
_base_0.__class = _class_0
AGif = _class_0
_module_0["AGif"] = AGif
return _module_0
