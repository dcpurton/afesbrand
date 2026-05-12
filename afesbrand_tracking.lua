-----------------------------------------------------------------------
--         FILE:  afesbrand-tracking.lua
--  DESCRIPTION:  part of afesbrand package
-----------------------------------------------------------------------

--- licence: GPL v2.0
--- copyright: PRAGMA ADE / ConTeXt Development Team
--- original authors: Hans Hagen, PRAGMA-ADE, Hasselt NL
--- luaotfload adaption: adapted by Philipp Gesang, Ulrike Fischer, Marcel Krüger
--- afesbrand adaptions: https://tex.stackexchange.com/a/762670

--- This code diverged quite a bit from its origin in Context. Please
--- do *not* report bugs on the Context list.

local node       = node
local nodedirect = node.direct

local getfield          = nodedirect.getfield
local setfield          = nodedirect.setfield
local getfont           = nodedirect.getfont
local getid             = nodedirect.getid
local getnext           = nodedirect.getnext
local setnext           = nodedirect.setnext
local getprev           = nodedirect.getprev
local setprev           = nodedirect.setprev
local getboth           = nodedirect.getboth
local setlink           = nodedirect.setlink
local getdisc           = nodedirect.getdisc
local getsubtype        = nodedirect.getsubtype
local getchar           = nodedirect.getchar
local getkern           = nodedirect.getkern
local setkern           = nodedirect.setkern
local getglue           = nodedirect.getglue
local setglue           = nodedirect.setglue
local hasattribute      = nodedirect.has_attribute
local setattribute      = nodedirect.set_attribute
local getattributelist  = nodedirect.getattributelist
local setattributelist  = nodedirect.setattributelist
local find_node_tail    = nodedirect.tail
local todirect          = nodedirect.todirect
local tonode            = nodedirect.tonode
local insert_before     = nodedirect.insert_before
local real_free_node    = nodedirect.free
local copy_node         = nodedirect.copy
local new_node          = nodedirect.new

local glyph_code   = node.id("glyph")
local kern_code    = node.id("kern")
local disc_code    = node.id("disc")
local glue_code    = node.id("glue")
local whatsit_code = node.id("whatsit")

local kerning_code    = 0
local userkern_code   = 1
local userskip_code   = 0
local spaceskip_code  = 13
local xspaceskip_code = 14

keepligature    = true
keeptogether    = false
keepwordspacing = false

local fonthashes  = fonts.hashes
local chardata    = fonthashes.characters
local identifiers = fonthashes.identifiers

if not chardata then
  chardata = { }
  table.setmetatableindex(chardata, function(t, k)
    if k == true then
      return chardata[currentfont()]
    else
      local tfmdata = font.getfont(k) or font.fonts[k]
      if tfmdata then
        local characters = tfmdata.characters
        t[k] = characters
        return characters
      end
    end
  end)
  fonthashes.characters = chardata
end

local markdata = setmetatable({}, {__index = function(t, k)
  if k == true then
    return t[currentfont()]
  else
    local tfmdata = font.getfont(k) or font.fonts[k]
    if tfmdata then
      local marks = tfmdata.resources.marks or {}
      t[k] = marks
      return marks
    end
  end
end})


local next   = next

local attr      = luatexbase.new_attribute("letterspace.factor")
local attr_done = luatexbase.new_attribute("letterspace.done")

local factors         = {}
local factor_to_value = {}

local function set_letterspace(factor)
  local val = factor_to_value[factor]
  if not val then
    val = #factors + 1
    factors[val]         = factor
    factor_to_value[factor] = val
  end
  tex.setattribute(attr, val)
end

local kernamounts = table.setmetatableindex(function(t, f)
  local tfmdata = font.getfont(f) or font.fonts[f]
  if tfmdata then
    local fontproperties = tfmdata.properties
    t[f] = fontproperties and fontproperties.kerncharacters ~= nil
    return t[f]
  end
  return false
end)

local function getkrn(n, fontid)
  local val = hasattribute(n, attr)
  local factor = val and factors[val]
  if factor then
    if kernamounts[fontid] then
      return nil
    end
    local tfmdata = font.getfont(fontid) or font.fonts[fontid]
    local quad    = tfmdata and tfmdata.parameters and tfmdata.parameters.quad or 0
    return factor * 0.01 * quad
  end
end

local attribute_table   = {}
local attribute_cleanup = {}

local function free_node(n)
  local k = attribute_cleanup[n]
  if k then
    attribute_cleanup[n], attribute_table[k] = nil
  end
  return real_free_node(n)
end

local function getprevreal(n)
  repeat n = getprev(n) until not n or getid(n) ~= whatsit_code
  return n
end

local function getnextreal(n)
  repeat n = getnext(n) until not n or getid(n) ~= whatsit_code
  return n
end

local function kernable_skip(n)
  local st = getsubtype(n)
  return st == userskip_code
      or st == spaceskip_code
      or st == xspaceskip_code
end

local function kern_injector(kern)
    local g = new_node(kern_code)
    setkern(g, kern)
    return g
end

local kerncharacters

kerncharacters = function(head)
  local start       = head
  local lastfont    = nil
  local keeptogether = keeptogether

  local keepligature = keepligature
  if type(keepligature) ~= "function" then
    local v = keepligature; keepligature = function() return v end
  end

  local keepwordspacing = keepwordspacing
  if type(keepwordspacing) ~= "function" then
    local v = keepwordspacing; keepwordspacing = function() return v end
  end

  local firstkern = true

  while start do
    local id = getid(start)

    if id == glyph_code then

      if hasattribute(start, attr_done, 1) then
        firstkern = false
        goto nextnode
      end

      local fontid      = getfont(start)
      local krn = getkrn(start, fontid)

      if not krn or krn == 0 then
        firstkern = true
        goto nextnode
      elseif firstkern then
        firstkern = false
        if not getfield(start, "components") then
          goto nextnode
        end
      end

      lastfont = fontid

      local c = getfield(start, "components")
      if c then
        if keepligature(start) then
          c = nil
        else
          while c do
            local s    = start
            local p, n = getboth(s)
            if p then setlink(p, c) else head = c end
            if n then setlink(find_node_tail(c), n) end
            start = c
            setfield(s, "components", nil)
            free_node(s)
            c = getfield(start, "components")
          end
        end
      end

      local prev = getprevreal(start)
      if prev then
        local pid = getid(prev)

        if pid == glue_code
           and kernable_skip(prev)
           and not keepwordspacing(prev, lastfont)
        then
          local wd, stretch, shrink = getglue(prev)
          if wd > 0 then
            local newwd = wd + krn
            local s2    = (stretch * newwd) / wd
            local sh2   = (shrink  * newwd) / wd
            setglue(prev, newwd, s2, sh2, 0, 0)
          end

        elseif pid == kern_code then
          local psub = getsubtype(prev)
          if psub == kerning_code or psub == userkern_code then
            local pprev = getprevreal(prev)
            if keeptogether
               and pprev and getid(pprev) == glyph_code
               and keeptogether(pprev, start)
            then
              -- keep
            else
              setkern(prev, getkern(prev) + krn)
            end
          end

        elseif pid == glyph_code then
          if getfont(prev) == lastfont then
            local prevchar = getchar(prev)
            local lastchar = getchar(start)
            if not (keeptogether and keeptogether(prev, start))
               and identifiers[lastfont]
            then
              local lastfontchars = chardata[lastfont]
              if lastfontchars then
                local prevchardata = lastfontchars[prevchar]
                if prevchardata then
                  local kern = 0
                  local kerns = prevchardata.kerns
                  if kerns then kern = kerns[lastchar] or kern end
                  local effective = kern + (markdata[lastfont][lastchar] and 0 or krn)
                  insert_before(head, start, kern_injector(effective))
                end
              end
            end
          else
            insert_before(head, start, kern_injector(krn))
          end

        elseif pid == disc_code then
          local disc               = prev
          local pre, post, replace = getdisc(disc)
          local prv                = getprevreal(disc)
          local nxt                = getnextreal(disc)

          if pre and prv then
            local before = copy_node(prv)
            setprev(pre, before); setnext(before, pre); setprev(before, nil)
            pre = kerncharacters(before)
            pre = getnext(pre)
            setprev(pre, nil)
            setfield(disc, "pre", pre)
            free_node(before)
          end

          if post and nxt then
            local after = copy_node(nxt)
            local tail  = find_node_tail(post)
            setnext(tail, after); setprev(after, tail)
            post = kerncharacters(post)
            setnext(getprev(after), nil)
            setfield(disc, "post", post)
            free_node(after)
          end

          if replace and prv and nxt then
            local before = copy_node(prv)
            local after  = copy_node(nxt)
            local tail   = find_node_tail(replace)
            setprev(replace, before); setnext(before, replace); setprev(before, nil)
            setnext(tail,    after);  setprev(after,  tail);    setnext(after, nil)
            replace = kerncharacters(before)
            replace = getnext(replace)
            setprev(replace, nil)
            setnext(getprev(after), nil)
            setfield(disc, "replace", replace)
            free_node(after); free_node(before)

          elseif identifiers[lastfont] then
            if prv and getid(prv) == glyph_code and getfont(prv) == lastfont then
              local kern     = 0
              local prevchar = getchar(prv)
              local lastchar = getchar(start)
              local lfc      = chardata[lastfont]
              if lfc then
                local pcd = lfc[prevchar]
                if pcd then
                  local kerns = pcd.kerns
                  if kerns then kern = kerns[lastchar] or kern end
                end
              end
              krn = kern + (markdata[lastfont][lastchar] and 0 or krn)
            end
            setfield(disc, "replace", kern_injector(krn))
          end
        end -- pid cases

        local attr_list     = getattributelist(start)
        local new_attr_list = attribute_table[attr_list]
        if new_attr_list then
          setattributelist(start, new_attr_list)
        else
          setattribute(start, attr_done, 1)
          attribute_cleanup[start] = attr_list
          attribute_table[attr_list] = getattributelist(start)
        end
      end -- if prev
    end -- glyph_code

    ::nextnode::
    if start then start = getnext(start) end
  end

  return head
end

local function process(head)
  if not head then return head end
  local result = kerncharacters(head)
  for k, v in next, attribute_cleanup do
    attribute_cleanup[k], attribute_table[v] = nil
  end
  return result
end

luatexbase.add_to_callback("post_shaping_filter", function(head)
    return tonode(process(todirect(head)))
end, "apply letterspacing")

local function_table = lua.get_functions_table()
local luafnalloc = luatexbase.new_luafunction('__afesbrand_set_tracking:n')
token.set_lua('__afesbrand_set_tracking:n', luafnalloc, 'protected')
function_table[luafnalloc] = function()
  local factor = tonumber(token.scan_string())
  if factor then
    set_letterspace(factor)
  else
    tex.setattribute(attr, -0x7FFFFFFF)
  end
end
