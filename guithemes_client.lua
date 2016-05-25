-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local ipairs = ipairs;
local pairs = pairs;

local config = false;
local manager = false;
local themesNode;
local theme = false;
local templateDir = {};
local templateDirList = {};
local templateList = {};
local templates = {};

local themeConfig = xmlLoadFile("themes.xml");

if not (themeConfig) then
	themeConfig = xmlCreateFile("themes.xml", "themes");
	themesNode = xmlCreateNodeEx("themes");
else
	themesNode = xmlGetNode(themeConfig);
end

local function addTheme(name)
	if (xmlFindSubNodeEx(themesNode, name)) then return false; end;

	local node = xmlCreateChildEx(themesNode, name);
	
	if not (node) then return false; end;
	
	local config = xmlCreateFile("themes/" .. name .. ".xml", "theme");
	
	if not (config) then return false; end;
	
	xmlCreateChild(config, "templates");
	xmlSaveFile(config);
	xmlUnloadFile(config);
	return true;
end

local function getThemeID(name)
	local m,n;
	
	for m,n in ipairs(themesNode.children) do
		if (n.name == name) then
			return m;
		end
	end
	
	return false;
end

local function removeTheme(name)
	local node = xmlFindSubNodeEx(themesNode, name);

	if not (node) then return false; end;
	
	xmlDestroyNodeEx(node);
	
	fileDelete("themes/" .. name .. ".xml");
	return true;
end

local function loadTheme(name)
	local xml = xmlLoadFile("themes/" .. name .. ".xml");
	
	if not (xml) then return false; end;

	local node = xmlGetNode(xml);
	local templateNode = findCreateNode(node, "templates");
	local theme = createTheme(name);
	
	return theme;
end

local global;
local window;
local msgBox;
local tabPanel;
local button;
local frames;
local editing;
local editBox;
local editor;
local listBox;
local menu;
local dropDown;
local scrollbar;
local hint;
local colorSelect;
local comboBox;
local checkBox;

function themeRegisterTemplate(name)
	local entry = {};
	local properties = {};
	local propByName = {};
	local links = {};
	local elemList = {};
	
	local function addProperty(name, desc, setHandler, resetHandler)
		local prop = {
			name = name,
			desc = desc,
			set = setHandler,
			reset = resetHandler
		};
		
		propByName[name] = prop;
		table.insert(properties, prop);
		return prop;
	end
	
	function entry.addColorProperty(name, desc, setHandler, resetHandler)
		local prop = addProperty(name, desc, setHandler, resetHandler);
		prop.type = "color";
		
		local template = templates[name];
		
		if (template) then
			template.addColorProperty(name, desc, setHandler, resetHandler);
		end
		
		return prop;
	end
	
	function entry.link(sub)
		local m,n;
		
		for m,n in ipairs(sub.properties) do
			propByName[n.name] = n;
		end
	
		table.insert(links, sub);
		
		if (theme) then
			templates[name].link(templates[sub.name]);
		end
	end
	
	function entry.register(elem)
		local template = templates[name];
		
		if (template) then
			template.register(elem);
		end
	
		function elem.destroy()
			table.delete(elemList, elem);
		end
		
		table.insert(elemList, elem);
		return true;
	end
	
	entry.name = name;
	entry.properties = properties;
	entry.propByName = propByName;
	entry.links = links;
	entry.elements = elemList;
	
	templateDir[name] = entry;
	table.insert(templateDirList, entry);
	
	if (theme) then
		theme.establishTemplate(name);
	end
	
	return entry;
end

-- Register theme applicators
global = themeRegisterTemplate("global");
global.addColorProperty("bgColor", "Background Color",
	function(elem, r, g, b)
		elem.setBackgroundColor(r, g, b);
	end,
	function(elem)
		elem.resetBackgroundColor();
	end
);
global.addColorProperty("textColor", "Text Color",
	function(elem, r, g, b)
		elem.setTextColor(r, g, b);
	end,
	function(elem)
		elem.resetTextColor();
	end
);

window = themeRegisterTemplate("window");
window.link(global);
window.addColorProperty("headLeftColor", "Heading Left Color",
	function(wnd, r, g, b)
		wnd.setHeadingLeftColor(r, g, b);
	end,
	function(wnd)
		wnd.resetHeadingLeftColor();
	end
);
window.addColorProperty("headRightColor", "Heading Right Color",
	function(wnd, r, g, b)
		wnd.setHeadingRightColor(r, g, b);
	end,
	function(wnd)
		wnd.resetHeadingRightColor();
	end
);

msgBox = themeRegisterTemplate("msgBox");
msgBox.link(window);

tabPanel = themeRegisterTemplate("tabPanel");
tabPanel.link(global);
tabPanel.addColorProperty("deactiveColor", "Deactivate Tab Color",
	function(panel, r, g, b)
		panel.setDeactiveTextColor(r, g, b);
	end,
	function(panel)
		panel.resetDeactiveTextColor();
	end
);

button = themeRegisterTemplate("button");
button.link(global);
button.addColorProperty("hoverColor", "Hover Color",
	function(elem, r, g, b)
		elem.setHoverColor(r, g, b);
	end,
	function(elem)
		elem.resetHoverColor();
	end
);
button.addColorProperty("disableBgColor", "Disabled Background Color",
	function(elem, r, g, b)
		elem.setDisabledBackgroundColor(r, g, b);
	end,
	function(elem)
		elem.resetDisabledBackgroundColor();
	end
);
button.addColorProperty("disableTextColor", "Disabled Text Color",
	function(elem, r, g, b)
		elem.setDisabledTextColor(r, g, b);
	end,
	function(elem)
		elem.resetDisabledTextColor();
	end
);

frames = themeRegisterTemplate("frames");
frames.addColorProperty("frameColor", "Frame Color",
	function(elem, r, g, b)
		elem.setFrameColor(r, g, b);
	end,
	function(elem)
		elem.resetFrameColor();
	end
);

editing = themeRegisterTemplate("editing");
editing.link(global);
editing.addColorProperty("disableBgColor", "Disabled Background Color",
	function(elem, r, g, b)
		elem.setDisabledBackgroundColor(r, g, b);
	end,
	function(elem)
		elem.resetDisabledBackgroundColor();
	end
);

editBox = themeRegisterTemplate("editBox");
editBox.link(editing);
editBox.link(frames);

editor = themeRegisterTemplate("editor");
editor.link(editing);
editor.addColorProperty("highlightColor", "Highlight Color",
	function(elem, r, g, b)
		elem.setHighlightColor(r, g, b, 0x7F);
	end,
	function(elem)
		elem.resetHighlightColor();
	end
);

listBox = themeRegisterTemplate("listBox");
listBox.link(global);
listBox.addColorProperty("row1color", "First Row Item Color",
	function(list, r, g, b)
		list.setRow1Color(r, g, b);
	end,
	function(list)
		list.resetRow1Color();
	end
);
listBox.addColorProperty("row2color", "Second Row Item Color",
	function(list, r, g, b)
		list.setRow2Color(r, g, b);
	end,
	function(list)
		list.resetRow2Color();
	end
);
listBox.addColorProperty("selectColor", "Selection Color",
	function(list, r, g, b)
		list.setSelectionColor(r, g, b);
	end,
	function(list)
		list.resetSelectionColor();
	end
);
listBox.addColorProperty("headingColor", "Heading Background Color",
	function(list, r, g, b)
		list.setHeaderColor(r, g, b);
	end,
	function(list)
		list.resetHeaderColor();
	end
);
listBox.addColorProperty("activeHeadingColor", "Active Heading Background Color",
	function(list, r, g, b)
		list.setActiveHeaderColor(r, g, b);
	end,
	function(list)
		list.resetActiveHeaderColor();
	end
);

menu = themeRegisterTemplate("menu");
menu.link(global);
menu.addColorProperty("selectionColor", "Selection Hover Color",
	function(menu, r, g, b)
		menu.setSelectionColor(r, g, b);
	end,
	function(menu)
		menu.resetSelectionColor();
	end
);

dropDown = themeRegisterTemplate("dropDown");
dropDown.link(global);
dropDown.addColorProperty("selectionColor", "Selection Hover Color",
	function(elem, r, g, b)
		elem.setSelectionColor(r, g, b);
	end,
	function(elem)
		elem.resetSelectionColor();
	end
);

scrollbar = themeRegisterTemplate("scrollbar");
scrollbar.addColorProperty("bgColor", "Background Color",
	function(scroll, r, g, b)
		scroll.setBackgroundColor(r, g, b);
	end,
	function(scroll)
		scroll.resetBackgroundColor();
	end
);
scrollbar.addColorProperty("sliderColor", "Slider Color",
	function(scroll, r, g, b)
		scroll.setSliderColor(r, g, b);
	end,
	function(scroll)
		scroll.resetSliderColor();
	end
);
scrollbar.addColorProperty("buttonBgColor", "Scroll Button Background Color",
	function(scroll, r, g, b)
		scroll.setButtonBackgroundColor(r, g, b);
	end,
	function(scroll)
		scroll.resetButtonBackgroundColor();
	end
);
scrollbar.addColorProperty("buttonColor", "Scrolling Button Color",
	function(scroll, r, g, b)
		scroll.setButtonColor(r, g, b);
	end,
	function(scroll)
		scroll.resetButtonColor();
	end
);

hint = themeRegisterTemplate("hint");
hint.link(global);

colorSelect = themeRegisterTemplate("colorSelect");
colorSelect.link(window);

comboBox = themeRegisterTemplate("comboBox");
comboBox.link(global);
comboBox.link(frames);

checkBox = themeRegisterTemplate("checkBox");
checkBox.link(global);
checkBox.addColorProperty("hoverColor", "Hover Color",
	function(elem, r, g, b)
		elem.setHoverColor(r, g, b);
	end,
	function(elem)
		elem.resetHoverColor();
	end
);
-- THEME APPLICATORS END

function themeFindTemplate(name)
	return templateDir[name];
end

local dropDowns = {};
local menus = {};
local windows = {};
local msgBoxes = {};
local tabPanels = {};
local buttons = {};
local editBoxes = {};
local scrollPanes = {};
local editors = {};
local listBoxes = {};
local scrollbars = {};
local hints = {};
local colorSelects = {};
local comboBoxes = {};
local checkBoxes = {};

local function registerDropDown(elem)
	table.insert(dropDowns, elem);

	function elem.addSubList(...)
		local ret = { super(...) };
		registerDropDown(ret[1]);
		return unpack(ret);
	end
	
	dropDown.register(elem);
end

local function registerMenu(elem)
	table.insert(menus, elem);

	function elem.addItem(...)
		local sub = super(...);
		registerDropDown(sub);
		return sub;
	end
	
	menu.register(elem);
end

function themeCreateWindow(...)
	local elem = createWindow(...);
	
	if not (elem) then return false; end;
	
	table.insert(windows, elem);
	
	window.register(elem);
	
	function elem.doMenu()
		local elem = super();
		registerMenu(elem);
		return elem;
	end
	
	return elem;
end

function themeCreateMsgBox(msg, setting, parent)
	local elem = createMsgBox(msg, setting, parent);
	
	if not (elem) then return false; end;
	
	table.insert(msgBoxes, elem);
	
	msgBox.register(elem);
	
	local children = elem.getRoot().getChildren();
	
	if not (setting) or (setting == "info") then
		button.register(children[1]);
	elseif (setting == "confirm") then
		button.register(children[1]);
		button.register(children[2]);
	elseif (setting == "input") then
		editBox.register(children[1]);
		button.register(children[2]);
		button.register(children[3]);
	end
	
	return elem;
end

function themeCreateTabPanel(...)
	local elem = createTabPanel(...);
	
	if not (elem) then return false; end;
	
	table.insert(tabPanels, elem);
	
	tabPanel.register(elem);
	return elem;
end

function themeCreateButton(...)
	local elem = createButton(...);
	
	if not (elem) then return false; end;
	
	table.insert(buttons, elem);
	
	button.register(elem);
	return elem;
end

function themeCreateEditBox(...)
	local elem = createEditBox(...);
	
	if not (elem) then return false; end;
	
	table.insert(editBox, elem);
	
	editBox.register(elem);
	return elem;
end

local function registerScrollPane(pane)
	table.insert(scrollPanes, pane);

	local children = pane.getChildren();
	scrollbar.register(children[1]);
	scrollbar.register(children[2]);
end

function themeCreateEditor(...)
	local elem = createEditor(...);
	
	if not (elem) then return false; end;
	
	table.insert(editors, elem);
	
	editor.register(elem);
	registerScrollPane(elem.getScrollBuffer());
	return elem;
end

function themeCreateListBox(...)
	local elem = createListBox(...);
	
	if not (elem) then return false; end;
	
	table.insert(listBoxes, elem);
	
	listBox.register(elem);
	registerScrollPane(elem.getPane());
	return elem;
end

function themeCreateMenu(...)
	local elem = createMenu(...);
	
	if not (elem) then return false; end;
	
	registerMenu(elem);
	return elem;
end

function themeCreateDropDown(...)
	local elem = createDropDown(...);
	
	if not (elem) then return false; end;
	
	registerDropDown(elem);
	return elem;
end

function themeCreateScrollbar(...)
	local elem = createScrollbar(...);
	
	if not (elem) then return false; end;
	
	table.insert(scrollbars, elem);
	
	scrollbar.register(elem);
	return elem;
end

function themeCreateHint(...)
	local elem = createHint(...);
	
	if not (elem) then return false; end;
	
	table.insert(hints, elem);
	
	hint.register(elem);
	return elem;
end

function themeCreateColorSelect(...)
	local elem = createColorSelect(...);
	
	if not (elem) then return false; end;
	
	table.insert(colorSelects, elem);
	
	colorSelect.register(elem);
	
	tabPanel.register(elem.getHUETabPanel());
	
	local r, g, b = elem.getColorEditBoxes();
	editBox.register(r);
	editBox.register(g);
	editBox.register(b);
	
	button.register(elem.getCloseButton());
	
	return elem;
end

function themeCreateComboBox(...)
	local elem = createComboBox(...);
	
	if not (elem) then return false; end;
	
	table.insert(comboBoxes, elem);
	
	comboBox.register(elem);
	return elem;
end

function themeCreateCheckBox(...)
	local elem = createCheckBox(...);
	
	if not (elem) then return false; end;
	
	table.insert(checkBoxes, elem);
	
	checkBox.register(elem);
	return elem;
end

function themeLoad(name)
	themeUnload();
	
	local xml = xmlLoadFile("themes/" .. name .. ".xml");
	
	if not (xml) then return false; end;
	
	local t_node = xmlGetNode(xml);
	local templatesNode = findCreateNode(t_node, "templates");
	theme = createClass();
	
	function theme.getName()
		return name;
	end
	
	local function loadTemplate(node, name)
		local template = createClass();
		local links = {};
		local backdrops = {};
		local properties = {};
		local propertyList = {};
		local setHandlers = {};
		local resetHandlers = {};
		local elements = {};
		local elemConfig = {};
		local tostring = tostring;
		
		function template.getName()
			return name;
		end
		
		local function createProperty(id, desc)
			local prop = createClass();
			local propNode;
			local active = false;
			
			if not (desc) then
				desc = id;
			end
			
			function prop.getType()
				return "property";
			end
			
			function prop.getPropType()
				return "unk";
			end
			
			function prop.getName()
				return id;
			end
			
			function prop.getDescription()
				return desc;
			end
			
			function prop.setDescription(text)
				desc = text;
				return true;
			end
			
			function prop.setNode(n)
				propNode = n;
				
				setActive(true);
			end
			
			function prop.getNode()
				return propNode;
			end
			
			function prop.initNode(propNode)
				return;
			end
			
			function prop.createNode()
				if (propNode) then
					return propNode;
				end
			
				propNode = xmlCreateChildEx(node, id);
				initNode(propNode);
				
				setActive(true);
				return propNode;
			end
			
			function prop.destroyNode()
				if not (propNode) then return; end;
				
				xmlDestroyNodeEx(propNode);
				
				propNode = false;
			end
			
			function prop.getID()
				local m,n;
				
				for m,n in ipairs(propertyList) do
					if (n == prop) then
						return m;
					end
				end
				
				return 1;
			end
			
			function prop.getTemplate()
				return template;
			end
			
			function prop.determine()
				return;
			end
			
			function prop.getAttributes()
				return;
			end
			
			function prop.setAttributes()
				setActive(true);
				
				applyAll();
				
				if (manager) then
					manager.updateProperty(template, prop);
				end
				
				castShadow();
			end
			
			function prop.save()
				return;
			end
			
			function prop.getSetHandler()
				return setHandlers[id];
			end
			
			function prop.getResetHandler()
				return resetHandlers[id];
			end
			
			function prop.setActive(enable)
				active = enable;
				return true;
			end
			
			function prop.isActive()
				return active;
			end
			
			function prop.castShadow()
				local m,n;
				
				for m,n in ipairs(backdrops) do
					local sub = n.findProperty(id);
					
					if (sub) and (sub.getType() == getType()) and not (sub.getNode()) and (isActive()) then
						sub.setAttributes(getAttributes());
					end
				end
			end
			
			function prop.apply(elem)
				if not (active) then return; end;
				
				setHandlers[id](elem, getAttributes());
			end
			
			function prop.tostring()
				return "";
			end
			
			function prop.applyAll()
				local m,n;
				
				for m,n in ipairs(elements) do
					apply(n);
				end
				
				return true;
			end
			
			function prop.performListBox(list, c, r)
				return;
			end
			
			function prop.cleanUp()
				if not (active) then return; end;
				
				setActive(false);
				
				local m,n;
				local handler = resetHandlers[id];
				
				if not (handler) then return; end;
				
				for m,n in ipairs(elements) do
					handler(n);
				end
			end
			
			function prop.destroy()
				cleanUp();
			
				properties[id] = nil;
				table.delete(propertyList, prop);
			end
			
			properties[id] = prop;
			table.insert(propertyList, prop);
			return prop;
		end
		
		function template.putBackdrop(elem)
			table.insert(backdrops, elem);
			
			function elem.destroy()
				if not (backdrops) then return; end;
			
				table.delete(backdrops, elem);
			end
		end
		
		function template.link(sub)
			sub.putBackdrop(template);
		
			table.insert(links, sub);
			
			local m,n;
			
			for m,n in ipairs(sub.getPropertyList()) do
				local prop;
				local name = n.getName();
				
				prop = addCompositeProperty(n.getPropType(), name, n.getDescription());
				
				if not (prop.isActive()) and (n.isActive()) then
					prop.setAttributes(n.getAttributes());
				end
				
				local setHandler = n.getSetHandler();
				local resetHandler = n.getResetHandler();
				
				if (setHandler) then
					setHandlers[name] = setHandler;
				end
				
				if (resetHandler) then
					resetHandlers[name] = resetHandler;
				end
			end
		end
		
		function template.addColorProperty(id, desc, setHandler, resetHandler)
			local property = properties[id];
			
			if (property) then
				if (desc) then
					property.setDescription(desc);
				end
			else
				property = createProperty(id, desc);
				local r, g, b = 0xFF, 0xFF, 0xFF;
				local cselect = false;
				
				function property.getType()
					return "colorProperty";
				end
				
				function property.getPropType()
					return "color";
				end
				
				function property.getAttributes()
					return r, g, b;
				end
				
				function property.setAttributes(_r, _g, _b)
					r, g, b = _r, _g, _b;
					
					super();
				end
				
				function property.save()
					local node = property.createNode();
					node.attr.r = tostring(r);
					node.attr.g = tostring(g);
					node.attr.b = tostring(b);
				end
				
				function property.initNode(node)
					node.attr.type = "color";
				end
				
				function property.setNode(node)
					super(node);
					
					setAttributes(tonumber(node.attr.r), tonumber(node.attr.g), tonumber(node.attr.b));
				end
				
				function property.determine()
					if (cselect) then
						local w, h = cselect.getParent().getSize();
						cselect.setPosition((w - cselect.width) / 2, (h - cselect.height) / 2);
						cselect.moveToFront();
						return;
					end
					
					cselect = themeCreateColorSelect();
					
					if not (cselect) then
						local msg = createMsgBox("Your GPU has to support Pixel Shader 2.0!");
						msg.setText("GUI Error");
						return;
					end
					
					local w, h = cselect.getParent().getSize();
					cselect.setPosition((w - cselect.width) / 2, (h - cselect.height) / 2);
					cselect.setSelectedColor(r, g, b);
					
					function cselect.events.onColorSelect(r, g, b)
						property.setAttributes(r, g, b);
						
						property.save();
					end
					
					function cselect.destroy()
						cselect = false;
					end
				end
				
				function property.tostring()
					if not (isActive()) then
						return "Not set";
					end
				
					return "Red: " .. r .. ", Green: " .. g .. ", Blue: " .. b;
				end
				
				function property.performListBox(list, c, row)
					if not (isActive()) then
						list.setItemColor(c, row, 0xFF, 0xFF, 0xFF);
						return;
					end
				
					list.setItemColor(c, row, r, g, b);
				end
				
				function property.destroy()
					if (cselect) then
						cselect.destroy();
					end
				end
			end
		
			if (setHandler) then
				setHandlers[id] = setHandler;
			end
			
			if (resetHandler) then
				resetHandlers[id] = resetHandler;
			end
			
			return property;
		end
		
		function template.addCompositeProperty(type, name, desc)
			if (type == "color") then
				return addColorProperty(name, desc);
			end
			
			return createProperty(name, desc);
		end
		
		-- Apply the node
		local m,n;
		
		for m,n in ipairs(node.children) do
			local prop = template.addCompositeProperty(n.attr.type, n.name);
			prop.setNode(n);
		end
		
		function template.getProperties()
			local props = {};
			local m,n;
			
			for m,n in ipairs(links) do
				local j,k;
				
				for j,k in pairs(n.getProperties()) do
					props[j] = k;
				end
			end
			
			for m,n in pairs(properties) do
				props[m] = n;
			end
			
			return props;
		end
		
		function template.getPropertyList()
			return propertyList;
		end
		
		function template.findProperty(name)
			return properties[name];
		end
		
		template.set = setHandlers;
		template.reset = resetHandlers;
		
		function template.register(elem)
			table.insert(elements, elem);
			
			-- Set up special per-element access
			local config = {};
			elemConfig[elem] = config;
			
			local context = elem.createContext();
			config.context = context;
			
			function context.events.onDestruction()
				elemConfig[elem] = nil;
				table.delete(elements, elem);
			end
			
			-- Apply the properties to the element
			local m,n;
			
			for m,n in ipairs(propertyList) do
				n.apply(elem);
			end
			
			return true;
		end
		
		function template.destroy()
			local m,n;
		
			-- Clean up associations with any yet active element
			for m,n in ipairs(propertyList) do
				n.cleanUp();
			end
			
			-- Destroy virtual contexts
			for m,n in ipairs(elements) do
				elemConfig[n].context.destroy();
			end
			
			while not (#propertyList == 0) do
				propertyList[1].destroy();
			end
		
			-- Free properties
			set = nil;
			reset = nil;
			setHandlers = nil;
			resetHandlers = nil;
			propertyList = nil;
			properties = nil;
			links = nil;
			handlers = nil;
			elements = nil;
			backdrops = nil;
			
			templates[name] = nil;
			table.delete(templateList, template);
		end
		
		templates[name] = template;
		table.insert(templateList, template);
		return template;
	end
	
	local m,n;
	
	for m,n in ipairs(templatesNode.children) do
		loadTemplate(n, n.name);
	end
	
	function theme.establishTemplate(name)
		if (templates[name]) then
			return templates[name];
		end
		
		return loadTemplate(xmlCreateChildEx(templatesNode, name), name);
	end
	
	-- Set up the association tree and elements
	for m,n in ipairs(templateDirList) do
		local assoc = theme.establishTemplate(n.name);
		local j,k;
		
		for j,k in pairs(n.propByName) do
			if (k.set) then
				assoc.set[j] = k.set;
			end
			
			if (k.reset) then
				assoc.reset[j] = k.reset;
			end
		end
		
		for j,k in ipairs(n.properties) do
			local prop = assoc.findProperty(k.name);
			
			if not (prop) then
				prop = assoc.addCompositeProperty(k.type, k.name, k.desc);
			elseif not (prop.getPropType() == k.type) then
				prop.destroy();
				prop = assoc.addCompositeProperty(k.type, k.name, k.desc);
			else
				prop.setDescription(k.desc);
			end
		end
		
		for j,k in ipairs(n.links) do
			assoc.link(templates[k.name]);
		end
		
		for j,k in ipairs(n.elements) do
			assoc.register(k);
		end
	end
	
	function theme.save()
		xmlSetNode(xml, t_node);
		xmlSaveFile(xml);
	end
	
	function theme.destroy()
		while not (#templateList == 0) do
			templateList[1].destroy();
		end
	
		xmlUnloadFile(xml);
	end
	
	if (manager) then
		manager.initTheme();
	end
	
	return true;
end

function themeUnload()
	if not (theme) then return true; end;
	
	if (manager) then
		manager.destroyTheme();
	end
	
	theme.destroy();
	
	theme = false;
	return true;
end

function showThemeManager(show)
	if (show) then
		if not (manager) then
			local m,n;
		
			manager = themeCreateWindow();
			
			if not (manager) then return false; end;
			
			local screenW, screenH = manager.getScreenSize();
			manager.setRootSize(550, 350);
			manager.setPosition((screenW - manager.width) / 2, (screenH - manager.height) / 2);
			manager.setText("Theme Control Center");
			
			local menu = manager.doMenu();
			
			local file = menu.addItem("File");
			
			local themeDrop;
			
			local function addManagerTheme(name)
				themeDrop.addItem(name, function()
						if not (themeLoad(name)) then
							themeCreateMsgBox("Failed to load theme '" .. name .. "'!");
							return false;
						end
					end
				);
			end
			
			file.addItem("Create Theme", function()
					local msg = themeCreateMsgBox("How will the theme be called?", "input");
					msg.setText("Template Name");
					
					function msg.events.onMsgBoxInput(name)
						if not (addTheme(name)) then
							themeCreateMsgBox("Failed to add theme '" .. name .. "'!");
							return;
						end
						
						addManagerTheme(name);
					end
				end
			);
			
			file.addItem("Delete Theme", function()
					if not (theme) then
						themeCreateMsgBox("No theme loaded!");
						return;
					end
					
					local name = theme.getName();
					
					themeUnload();
					themeDrop.removeItem(getThemeID(name));
					
					if not (removeTheme(name)) then
						themeCreateMsgBox("Failed to delete theme '" .. name .. "'!");
					end
				end
			);
			
			file.addBreak();
			
			file.addItem("Unload Theme", function()
					themeUnload();
				end
			);
			
			file.addBreak();
			
			file.addItem("Close", function()
					showThemeManager(false);
				end
			);
			
			themeDrop = menu.addItem("Themes");
			
			for m,n in ipairs(themesNode.children) do
				addManagerTheme(n.name);
			end
			
			local root = manager.getRoot();
			local template;
			local propList;
			
			local propertyList = themeCreateListBox(root);
			propertyList.setPosition(150, 10);
			propertyList.setSize(root.width - 160, root.height - 45);
			propertyList.addColumn();
			propertyList.setColumnName(1, "Property");
			propertyList.addColumn();
			propertyList.setColumnName(2, "Attributes");
			
			function propertyList.events.onListBoxConfirm()
				local selection = getSelection();
				
				if (#selection == 0) then return; end;
				
				propList[selection[1]].determine();
			end
			
			function manager.updateProperty(temp, prop)
				if not (template == temp) then return; end;
				
				local id = prop.getID();
				
				propertyList.setItemText(2, id, prop.tostring());
				prop.performListBox(propertyList, 2, id);
				
				propertyList.setColumnWidth(2, math.max(100, propertyList.getMinimumColumnWidth(2)));
			end
			
			local function selectTemplate(t)
				template = t;
				
				propertyList.clearRows();
				
				local m,n;
				propList = template.getPropertyList();
				
				for m,n in ipairs(propList) do
					propertyList.addRow();
					propertyList.setItemText(1, m, n.getDescription());
					propertyList.setItemText(2, m, n.tostring());
					
					n.performListBox(propertyList, 2, m);
				end
				
				propertyList.setColumnWidth(1, propertyList.getMinimumColumnWidth(1) + 10);
				propertyList.setColumnWidth(2, math.max(100, propertyList.getMinimumColumnWidth(2)));
			end
			
			local templateListBox = themeCreateListBox(root);
			templateListBox.setPosition(10, 10);
			templateListBox.setSize(125, root.height - 20);
			templateListBox.addColumn();
			templateListBox.setColumnName(1, "Template");
			templateListBox.setColumnWidth(1, templateListBox.width);
			
			function templateListBox.events.onListBoxSelect(id)
				selectTemplate(templateList[id]);
			end
			
			local clear = themeCreateButton(root);
			clear.setPosition(150, root.height - 30);
			clear.setSize(80, 20);
			clear.setText("Clear");
			
			local function clearProperty(template, prop)
				prop.destroyNode();
				prop.cleanUp();
				
				manager.updateProperty(template, prop);
			end
			
			templateListBox.addEventHandler("onKeyInput", function(button, state)
					if not (state) then return; end;
					
					if (button == "delete") then
						local m,n;
						
						for m,n in ipairs(templateListBox.getSelection()) do
							local j,k;
							
							for j,k in ipairs(templateList[n].getPropertyList()) do
								clearProperty(temp, k);
							end
						end
					end
				end
			);
			
			local function deleteSelection()
				local m,n;
				local selection = propertyList.getSelection();
				
				for m,n in ipairs(selection) do
					clearProperty(template, propList[n]);
				end
			end
			
			function clear.events.onPress()
				deleteSelection();
			end
			
			propertyList.addEventHandler("onKeyInput", function(button, state)
					if not (state) then return; end;
					
					if (button == "delete") then
						deleteSelection();
					end
				end
			);
			
			local save = themeCreateButton(root);
			save.setPosition(root.width - 220, root.height - 30);
			save.setSize(100, 20);
			save.setText("Save");
			save.setDisabled(true);
			
			function save.events.onPress()
				theme.save();
			end
			
			function manager.initTheme()
				-- Remember that we have a theme going
				editorNode.attr.theme = theme.getName();
				xmlNotify(editorNode, "set_attribute", "theme", theme.getName());
			
				-- Start out with global for every theme
				selectTemplate(templates.global);
				
				-- List all the theme's templates
				for m,n in ipairs(templateList) do
					templateListBox.addRow();
					templateListBox.setItemText(1, m, n.getName());
				end
				
				templateListBox.setColumnWidth(1, templateListBox.getMinimumColumnWidth(1));
				
				-- Setup working GUI
				save.setDisabled(false);
			end
			
			if (theme) then
				manager.initTheme();
			end
			
			function manager.destroyTheme()
				editorNode.attr.theme = nil;
				xmlNotify(editorNode, "unset_attribute", "theme");
			
				-- Disable GUI control
				save.setDisabled(true);
			
				templateListBox.clearRows();
				propertyList.clearRows();
			end
			
			local close = themeCreateButton(root);
			close.setPosition(root.width - 110, root.height - 30);
			close.setSize(100, 20);
			close.setText("Close");
			
			function close.events.onPress()
				showThemeManager(false);
			end
		elseif not (manager.visible) then
			manager.setVisible(true);
			manager.moveToFront();
		end
	elseif (manager) then
		manager.setVisible(false);
	end
	
	return true;
end

function saveThemes()
	xmlSetNode(themeConfig, themesNode);
	xmlSaveFile(themeConfig);
	
	xmlUnloadFile(themeConfig);
end