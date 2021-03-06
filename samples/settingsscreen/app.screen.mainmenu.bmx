SuperStrict
Import "../../base.gfx.sprite.bmx"
Import "../../base.framework.screen.bmx"
Import "../../base.util.registry.bmx"
Import "../../base.gfx.gui.button.bmx"
Import "../../base.gfx.gui.arrowbutton.bmx"
Import "../../base.gfx.gui.backgroundbox.bmx"
Import "../../base.gfx.gui.checkbox.bmx"
Import "../../base.gfx.gui.input.bmx"
Import "../../base.gfx.gui.textbox.bmx"
Import "../../base.gfx.gui.panel.bmx"
Import "../../base.gfx.gui.list.base.bmx"
Import "../../base.gfx.gui.list.selectlist.bmx"
Import "../../base.gfx.gui.list.slotlist.bmx"
Import "../../base.gfx.gui.dropdown.bmx"
Import "../../base.gfx.gui.window.base.bmx"
Import "../../base.gfx.gui.window.modal.bmx"
Import "../../base.util.interpolation.bmx"
Import "app.screen.bmx"

Type TScreenMainMenu extends TScreenMenuBase
	Field LogoFadeInFirstCall:int = 0
	'store it so we can check for existence later on
	global modalDialogue:TGUIModalWindow

	Method Setup:Int()
		local button:TGUIButton = new TGUIButton.Create(new TVec2D.Init(20,20), new TVec2D.Init(130,-1), "Clickeriki?", self.GetName())
		local input:TGUIInput = new TGUIInput.Create(new TVec2D.Init(20,55), new TVec2D.Init(130,-1), "empty", 20, self.GetName())
		input.SetOverlay("gfx_gui_icon_arrowRight")

		local arrow:TGUIArrowButton = new TGUIArrowButton.Create(new TVec2D.Init(155,20), null, "left", self.GetName())
		local checkbox:TGUICheckBox = new TGUICheckBox.Create(new TVec2D.Init(155,55), null, true, "checkbox", self.GetName())

		local text:TGUITextbox = new TGUITextbox.Create(new TVec2D.Init(20,90), new TVec2D.Init(100,100), "I am a multiline textbox. Not pretty but nice to have.", self.GetName())
		local panel:TGUIPanel = new TGUIPanel.Create(new TVec2D.Init(20,250), new TVec2D.Init(120, 150), self.GetName())
		panel.SetBackground( new TGUIBackgroundBox.Create(null, null) )
		panel.SetValue("press ~qspace~q to go to next screen")

		local baseList:TGUIListBase = new TGUIListBase.Create(new TVec2D.Init(20,450), new TVec2D.Init(130,80), self.GetName())
		'add some items to that list
		for local i:int = 1 to 10
			'base items do not have a size - so we have to give a manual one
			baseList.AddItem( new TGUIListItem.Create(null, new TVec2D.Init(100, 20), "basetest "+i) )
		Next


		local selectList:TGUISelectList = new TGUISelectList.Create(new TVec2D.Init(200,450), new TVec2D.Init(130,80), self.GetName())
		'add some items to that list
		for local i:int = 1 to 10
			'base items do not have a size - so we have to give a manual one
			selectList.AddItem( new TGUISelectListItem.Create(null, null, "selecttest "+i) )
		Next


		local slotList:TGUISlotList = new TGUISlotList.Create(new TVec2D.Init(350,450), new TVec2D.Init(130,120), self.GetName())
		slotList.SetSlotMinDimension(130, 20)
		'uncomment the following to make dropped items occupy the first
		'free slot
		'slotList.SetAutofillSlots(true)
		slotList.SetItemLimit(5) 'max 5 items
		'add some items to that list
		for local i:int = 1 to 3
			slotList.SetItemToSlot( new TGUIListItem.Create(null, new TVec2D.Init(130,20), "slottest "+i), i )
		Next

		'uncomment to have a simple image button
		'local imageButton:TGUIButton = new TGUIButton.Create(new TVec2D.Init(0,0), null, self.GetName())
		'imageButton.spriteName = "gfx_startscreen_logo"
		'imageButton.SetAutoSizeMode( TGUIButton.AUTO_SIZE_MODE_SPRITE )

		'a simple window
		local window:TGuiWindowBase = new TGUIWindowBase.Create(new TVec2D.Init(550,200), new TVec2D.Init(200,150), self.GetName())
		'as content area starts to late for automatic caption positioning
		'we set a specific area to use
		window.SetCaptionArea(new TRectangle.Init(-1,5,-1,25))
		window.SetCaption("testwindow")
		window.SetValue("content")


		'a modal dialogue
		local createModalDialogueButton:TGUIButton = new TGUIButton.Create(new TVec2D.Init(610,20), new TVec2D.Init(180,-1), "create modal window", self.GetName())
		'handle clicking on that button
		EventManager.RegisterListenerFunction("guiobject.onclick", onClickCreateModalDialogue, createModalDialogueButton)



		local dropdown:TGUIDropDown = new TGUIDropDown.Create(new TVec2D.Init(550,450), new TVec2D.Init(130,-1), self.GetName())
		'add some items to that list
		for local i:int = 1 to 10
			'base items do not have a size - so we have to give a manual one
			dropdown.AddItem( new TGUIDropDownItem.Create(null, null, "dropdown "+i) )
		Next

		'register demo click listener - only listen to click events of
		'the "button" created above
'		EventManager.RegisterListenerFunction("guiobject.onclick", onClickMyButton, button)
'		EventManager.RegisterListenerFunction("guiobject.onclick", onClickAGuiElement)
'		EventManager.RegisterListenerFunction("guiobject.onclick", onClickOnAButton, "tguibutton")
	End Method


	Function onClickCreateModalDialogue:Int(triggerEvent:TEventBase)
		modalDialogue = new TGUIModalWindow.Create(new TVec2D, new TVec2D.Init(400,250), "SYSTEM")
		modalDialogue.SetDialogueType(2)
		'as content area starts to late for automatic caption positioning
		'we set a specific area to use
		modalDialogue.SetCaptionArea(new TRectangle.Init(-1,5,-1,25))
		modalDialogue.SetCaptionAndValue("test modal window", "test content")

		print "created modal dialogue"
	End Function


	Function onClickAGuiElement:Int(triggerEvent:TEventBase)
		local obj:TGUIObject = TGUIObject(triggerEvent.GetSender())
		print "a gui element of type "+ obj.GetClassName() + " was clicked"
	End Function


	Function onClickOnAButton:Int(triggerEvent:TEventBase)
		'sender in this case is the gui object
		'cast as button to see if it is a button (or extends from one)
		local button:TGUIButton = TGuiButton(triggerEvent.GetSender())
		'not interested in other widgets
		if not button then return FALSE

		local mouseButton:Int = triggerEvent.GetData().GetInt("button")
		print "a TGUIButton just got clicked with mouse button "+mouseButton
	End Function


	Function onClickMyButton:Int(triggerEvent:TEventBase)
		'sender in this case is the gui object
		'cast as button to see if it is a button (or extends from one)
		local button:TGUIButton = TGuiButton(triggerEvent.GetSender())
		'not interested in other widgets
		if not button then return FALSE

		local mouseButton:Int = triggerEvent.GetData().GetInt("button")
		print "my button just got clicked with mouse button "+mouseButton
	End Function


	Method PrepareStart:Int()
		Super.PrepareStart()
		LogoFadeInFirstCall = 0
	End Method


	Method Update:Int()
		If KeyManager.IsHit(KEY_SPACE)
			GetScreenManager().GetCurrent().FadeToScreen( GetScreenManager().Get("room1") )
		Endif

		GuiManager.Update(self.name)
	End Method


	Field logoAnimStart:int = 0
	Field logoAnimTime:int = 1500
	Field logoScale:float = 0.0

	Method Render:int()
		Super.Render()

		local logo:TSprite = GetSpriteFromRegistry("gfx_startscreen_logo")
		if logo
			if logoAnimStart = 0 then logoAnimStart = Millisecs()
			logoScale = TInterpolation.BackOut(0.0, 1.0, Min(logoAnimTime, Millisecs() - logoAnimStart), logoAnimTime)
			logoScale :* TInterpolation.BounceOut(0.0, 1.0, Min(logoAnimTime, Millisecs() - logoAnimStart), logoAnimTime)

			local oldAlpha:float = GetAlpha()
			SetAlpha TInterpolation.RegularOut(0.0, 1.0, Min(0.5*logoAnimTime, Millisecs() - logoAnimStart), 0.5*logoAnimTime)

			logo.Draw( GraphicsWidth()/2, 150, -1, new TVec2D.Init(0.5, 0.5), logoScale)
			SetAlpha oldAlpha
		Endif



		GuiManager.Draw(self.name)
	End Method
End Type