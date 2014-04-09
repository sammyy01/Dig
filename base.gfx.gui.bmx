Rem
	===========================================================
	GUI Classes
	===========================================================

	TGuiManager - managing gui elements, handling update/render...
	TGUIObject - base class for gui objects to extend from
End Rem
SuperStrict
Import "base.gfx.sprite.bmx"
Import "base.gfx.bitmapfont.bmx"
Import "base.util.input.bmx"
Import "base.util.localization.bmx"
Import "base.util.registry.bmx"
Import "base.util.event.bmx"



'===== GUI CONSTANTS =====
Const GUI_OBJECT_DRAGGED:Int					= 2^0
Const GUI_OBJECT_VISIBLE:Int					= 2^1
Const GUI_OBJECT_ENABLED:Int					= 2^2
Const GUI_OBJECT_CLICKABLE:Int					= 2^3
Const GUI_OBJECT_DRAGABLE:Int					= 2^4
Const GUI_OBJECT_MANAGED:Int					= 2^5
Const GUI_OBJECT_POSITIONABSOLUTE:Int			= 2^6
Const GUI_OBJECT_IGNORE_POSITIONMODIFIERS:Int	= 2^7
Const GUI_OBJECT_IGNORE_PARENTPADDING:Int		= 2^8
Const GUI_OBJECT_ACCEPTS_DROP:Int				= 2^9
Const GUI_OBJECT_CAN_RECEIVE_KEYSTROKES:Int		= 2^10
Const GUI_OBJECT_DRAWMODE_GHOST:Int				= 2^11

'===== GUI STATUS CONSTANTS =====
CONST GUI_OBJECT_STATUS_APPEARANCE_CHANGED:Int	= 2^0

Const GUI_OBJECT_ORIENTATION_VERTICAL:Int		= 0
Const GUI_OBJECT_ORIENTATION_HORIZONTAL:Int		= 1


Global gfx_GuiPack:TSpritePack = new TSpritePack.Init(LoadImage("res/grafiken/GUI/guipack.png"), "guipack_pack")
gfx_GuiPack.AddSprite(New TSprite.Init(Null, "ListControl", new TRectangle.Init(96, 0, 56, 28), Null, 8, new TPoint.Init(14, 14)))
gfx_GuiPack.AddSprite(New TSprite.Init(Null, "DropDown", new TRectangle.Init(160, 0, 126, 42), Null, 21, new TPoint.Init(14, 14)))
gfx_GuiPack.AddSprite(New TSprite.Init(Null, "Slider", new TRectangle.Init(0, 30, 112, 14), Null, 8))
gfx_GuiPack.AddSprite(New TSprite.Init(Null, "Chat_IngameOverlay", new TRectangle.Init(0, 60, 504, 20), Null))


Type TGUIManager
	Field globalScale:Float	= 1.0
	'which state are we currently handling?
	Field currentState:String = ""
	'config about specific gui settings (eg. panelGap)
	Field config:TData = new TData
	Field List:TList = CreateList()
	Field ListReversed:TList = CreateList()
	'contains dragged objects (above normal)
	Field ListDragged:TList = CreateList()
	'contains dragged objects in reverse (for draw)
	Field ListDraggedReversed:TList	= CreateList()

	'=== UPDATE STATE PROPERTIES ===

	Field UpdateState_mouseButtonDown:Int[]
	Field UpdateState_mouseButtonHit:Int[]
	Field UpdateState_mouseScrollwheelMovement:Int = 0
	Field UpdateState_foundHitObject:Int = False
	Field UpdateState_foundHoverObject:Int = False

	'=== PRIVATE PROPERTIES ===

	Field _defaultfont:TBitmapFont
	Field _ignoreMouse:Int = False
	'is there an object listening to keystrokes?
	Field _keystrokeReceivingObject:TGUIObject = Null

	Global viewportX:Int=0,viewportY:Int=0,viewportW:Int=0,viewportH:Int=0
	Global _instance:TGUIManager


	Method New()
		if not _instance then self.Init()
		_instance = self
	End Method


	Function GetInstance:TGUIManager()
		if not _instance then _instance = new TGUIManager.Init()
		return _instance
	End Function


	Method Init:TGUIManager()
		'is something dropping on a gui element?
		EventManager.registerListenerFunction("guiobject.onDrop", TGUIManager.onDrop)

		'gui specific settings
		config.AddNumber("panelGap",10)

		Return self
	End Method


	Method GetDefaultFont:TBitmapFont()
		If Not _defaultFont Then _defaultFont = GetFontManager().Get("Default", 12)
		Return _defaultFont
	End Method


	Method GetDraggedCount:Int()
		Return ListDragged.count()
	End Method


	Method GetDraggedNumber:Int(obj:TGUIObject)
		Local pos:Int = 0
		For Local guiObject:TGUIObject = EachIn ListDragged
			If guiObject = obj Then Return pos
			pos:+1
		Next
		Return 0
	End Method


	'dragged are above normal objects
	Method AddDragged:Int(obj:TGUIObject)
		obj.setOption(GUI_OBJECT_DRAGGED, True)
		obj._timeDragged = MilliSecs()

		If ListDragged.contains(obj) Then Return False

		ListDragged.addLast(obj)
		ListDragged.sort(False, SortObjects)
		ListDraggedReversed = ListDragged.Reversed()

		Return True
	End Method


	Method RemoveDragged:Int(obj:TGUIObject)
		obj.setOption(GUI_OBJECT_DRAGGED, False)
		obj._timeDragged = 0
		ListDragged.Remove(obj)
		ListDragged.sort(False, SortObjects)
		ListDraggedReversed = ListDragged.Reversed()

		Return True
	End Method


	Function onDrop:Int( triggerEvent:TEventBase )
		Local guiobject:TGUIObject = TGUIObject(triggerEvent.GetSender())
		If guiobject = Null Then Return False

		'find out if it hit a list...
		Local coord:TPoint = TPoint(triggerEvent.GetData().get("coord"))
		If Not coord Then Return False
		Local potentialDropTargets:TGuiObject[] = GUIManager.GetObjectsByPos(coord, GUIManager.currentState, True, GUI_OBJECT_ACCEPTS_DROP)
		Local dropTarget:TGuiObject = Null

		For Local potentialDropTarget:TGUIobject = EachIn potentialDropTargets
			'do not ask other targets if there was already one handling that drop
			If triggerEvent.isAccepted() Then Continue
			'do not ask other targets if one object already aborted the event
			If triggerEvent.isVeto() Then Continue

			'inform about drag and ask object if it wants to handle the drop
			potentialDropTarget.onDrop(triggerEvent)

			If triggerEvent.isAccepted() Then dropTarget = potentialDropTarget
		Next

		'if we haven't found a dropTarget stop processing that event
		If Not dropTarget
			triggerEvent.setVeto()
			Return False
		EndIf

		'we found an object accepting the drop

		'ask if something does not want that drop to happen
		Local event:TEventSimple = TEventSimple.Create("guiobject.onTryDropOnTarget", new TData.Add("coord", coord) , guiobject, dropTarget)
		EventManager.triggerEvent( event )
		'if there is no problem ...just start dropping
		If Not event.isVeto()
			event = TEventSimple.Create("guiobject.onDropOnTarget", new TData.Add("coord", coord) , guiobject, dropTarget)
			EventManager.triggerEvent( event )
		EndIf

		'if there is a veto happening (dropTarget does not want the item)
		'also veto the onDropOnTarget-event
		If event.isVeto()
			triggerEvent.setVeto()
			Return False
		Else
			'inform others: we successfully dropped the object to a target
			EventManager.triggerEvent( TEventSimple.Create("guiobject.onDropOnTargetAccepted", new TData.Add("coord", coord) , guiobject, dropTarget ))
			'also add this drop target as receiver of the original-drop-event
			triggerEvent._receiver = dropTarget
			Return True
		EndIf
	End Function


	Method RestrictViewport(x:Int,y:Int,w:Int,h:Int)
		GetViewport(viewportX,viewportY,viewportW,viewportH)
		SetViewport(x,y,w,h)
	End Method


	Method ResetViewport()
		SetViewport(viewportX,viewportY,viewportW,viewportH)
	End Method


	Method Add:Int(obj:TGUIobject, skipCheck:Int=False)
		obj.setOption(GUI_OBJECT_MANAGED, True)

		If Not skipCheck And list.contains(obj) Then Return True

		List.AddLast(obj)
		ListReversed.AddFirst(obj)
		SortLists()
	End Method


	Function SortObjects:Int(ob1:Object, ob2:Object)
		Local objA:TGUIobject = TGUIobject(ob1)
		Local objB:TGUIobject = TGUIobject(ob2)

		'-1 = bottom
		' 1 = top


		'undefined object - "a>b"
		If objA And Not objB Then Return 1

		'if objA and objB are dragged elements
		If objA._flags & GUI_OBJECT_DRAGGED And objB._flags & GUI_OBJECT_DRAGGED
			'if a drag was earlier -> move to top
			If objA._timeDragged < objB._timeDragged Then Return 1
			If objA._timeDragged > objB._timeDragged Then Return -1
			Return 0
		EndIf
		'if only objA is dragged - move to Top
		If objA._flags & GUI_OBJECT_DRAGGED Then Return 1
		'if only objB is dragged - move to A to bottom
		If objB._flags & GUI_OBJECT_DRAGGED Then Return -1

		'if objA is active element - move to top
		If objA.hasFocus() Then Return 1
		'if objB is active element - move to top
		If objB.hasFocus() Then Return -1

		'if objA is invisible, move to to end
		If Not(objA._flags & GUI_OBJECT_VISIBLE) Then Return -1
		If Not(objB._flags & GUI_OBJECT_VISIBLE) Then Return 1

		'if objA is "higher", move it to the top
		If objA.rect.position.z > objB.rect.position.z Then Return 1
		'if objA is "lower"", move to bottom
		If objA.rect.position.z < objB.rect.position.z Then Return -1

		'run custom compare job
'		return objA.compare(objB)
		Return 0
	End Function


	Method SortLists()
		List.sort(True, SortObjects)

		ListReversed = List.Reversed()
	End Method


	'only remove from lists (object cleanup has to get called separately)
	Method Remove:Int(obj:TGUIObject)
		obj.setOption(GUI_OBJECT_MANAGED, False)

		List.remove(obj)
		ListReversed.remove(obj)

		RemoveDragged(obj)

		'no need to sort on removal as the order wont change then (just one less)
		'SortLists()
		Return True
	End Method


	Method IsState:Int(obj:TGUIObject, State:String)
		If State = "" Then Return True

		State = state.toLower()
		Local states:String[] = state.split("|")
		Local objStates:String[] = obj.GetLimitToState().toLower().split("|")
		For Local limit:String = EachIn states
			For Local objLimit:String = EachIn objStates
				If limit = objLimit Then Return True
			Next
		Next
		Return False
	End Method


	'returns whether an object is hidden/invisible/inactive and therefor
	'does not have to get handled now
	Method haveToHandleObject:Int(obj:TGUIObject, State:String="", fromZ:Int=-1000, toZ:Int=-1000)
		'skip if parent has not to get handled
		If(obj._parent And Not haveToHandleObject(obj._parent,State,fromZ,toZ)) Then Return False

		'skip if not visible
		If Not(obj._flags & GUI_OBJECT_VISIBLE) Then Return False

		'skip if not visible by zindex
		If Not ( (toZ = -1000 Or obj.rect.position.z <= toZ) And (fromZ = -1000 Or obj.rect.position.z >= fromZ)) Then Return False

		'limit display by state - skip if object is hidden in that state
		'deep check only if a specific state is wanted AND the object is limited to states
		If(state<>"" And obj.GetLimitToState() <> "")
			Return IsState(obj, state)
		EndIf
		Return True
	End Method


	'returns an array of objects at the given point
	Method GetObjectsByPos:TGuiObject[](coord:TPoint, limitState:String=Null, ignoreDragged:Int=True, requiredFlags:Int=0, limit:Int=0)
		If limitState=Null Then limitState = currentState

		Local guiObjects:TGuiObject[]
		'from TOP to BOTTOM (user clicks to visible things - which are at the top)
		For Local obj:TGUIobject = EachIn ListReversed
			'return array if we reached the limit
			If limit > 0 And guiObjects.length >= limit Then Return guiObjects

			If Not haveToHandleObject(obj, limitState) Then Continue

			'avoids finding the dragged object on a drop-event
			If Not ignoreDragged And obj.isDragged() Then Continue

			'if obj is required to accept drops, but does not so  - continue
			If (requiredFlags & GUI_OBJECT_ACCEPTS_DROP) And Not(obj._flags & GUI_OBJECT_ACCEPTS_DROP) Then Continue

			If obj.getScreenRect().containsXY( coord.getX(), coord.getY() )
				'add to array
				guiObjects = guiObjects[..guiObjects.length+1]
				guiObjects[guiObjects.length-1] = obj
			EndIf
		Next

		Return guiObjects
	End Method


	Method GetFirstObjectByPos:TGuiObject(coord:TPoint, limitState:String=Null, ignoreDragged:Int=True, requiredFlags:Int=0)
		Local guiObjects:TGuiObject[] = GetObjectsByPos(coord, limitState, ignoreDragged, requiredFlags, 1)

		If guiObjects.length = 0 Then Return Null Else Return guiObjects[0]
	End Method


	Method DisplaceGUIobjects(State:String = "", x:Int = 0, y:Int = 0)
		For Local obj:TGUIobject = EachIn List
			If isState(obj, State) Then obj.rect.position.MoveXY( x,y )
		Next
	End Method


	Method GetKeystrokeReceiver:TGUIobject()
		Return _keystrokeReceivingObject
	End Method


	Method SetKeystrokeReceiver:Int(obj:TGUIObject)
		If obj And obj.hasOption(GUI_OBJECT_CAN_RECEIVE_KEYSTROKES)
			_keystrokeReceivingObject = obj
		Else
			'just reset the old one
			_keystrokeReceivingObject = Null
		EndIf
	End Method


	Method GetFocus:TGUIObject()
		Return TGUIObject.GetFocusedObject()
	End Method


	Method SetFocus:Int(obj:TGUIObject)
		TGUIObject.SetFocusedObject(obj)

		'try to set as potential keystroke receiver
		SetKeystrokeReceiver(obj)
	End Method


	Method ResetFocus:Int()
		'remove focus (eg. when switching gamestates
		TGuiObject.SetFocusedObject(Null)

		'also remove potential keystroke receivers
		SetKeystrokeReceiver(Null)
	End Method


	'should be run on start of the current tick
	Method StartUpdates:Int()
		UpdateState_mouseScrollwheelMovement = MOUSEMANAGER.GetScrollwheelmovement()

		UpdateState_mouseButtonDown = MOUSEMANAGER.GetAllStatusDown()
		UpdateState_mouseButtonHit = MOUSEMANAGER.GetAllStatusHit() 'single and double clicks!
	End Method


	'run after all other gui things so important values can get reset
	Method EndUpdates:Int()
		'ignoreMouse can be useful for objects which know, that nothing
		'else should take care of mouse movement/clicks
		_ignoreMouse = False
	End Method


	Method Update(State:String = "", fromZ:Int=-1000, toZ:Int=-1000)
		'_lastUpdateTick :+1
		'if _lastUpdateTick >= 100000 then _lastUpdateTick = 0

		currentState = State

		UpdateState_mouseScrollwheelMovement = MOUSEMANAGER.GetScrollwheelmovement()

		UpdateState_foundHitObject = False
		UpdateState_foundHoverObject = False
		Local screenRect:TRectangle = Null

		'store a list of special elements - maybe the list gets changed
		'during update... some elements will get added/destroyed...
		Local ListDraggedBackup:TList = ListDragged

		'first update all dragged objects...
		For Local obj:TGUIobject = EachIn ListDragged
			If Not haveToHandleObject(obj,State,fromZ,toZ) Then Continue

			'avoid getting updated multiple times
			'this can be overcome with a manual "obj.Update()"-call
			'if obj._lastUpdateTick = _lastUpdateTick then continue
			'obj._lastUpdateTick = _lastUpdateTick

			obj.Update()
			'fire event
			EventManager.triggerEvent( TEventSimple.Create( "guiobject.onUpdate", Null, obj ) )
		Next

		'then the rest
		For Local obj:TGUIobject = EachIn ListReversed 'from top to bottom
			'all dragged objects got already updated...
			If ListDraggedBackup.contains(obj) Then Continue

			If Not haveToHandleObject(obj,State,fromZ,toZ) Then Continue

			'avoid getting updated multiple times
			'this can be overcome with a manual "obj.Update()"-call
			'if obj._lastUpdateTick = _lastUpdateTick then continue
			'obj._lastUpdateTick = _lastUpdateTick
			obj.Update()
			'fire event
			EventManager.triggerEvent( TEventSimple.Create( "guiobject.onUpdate", Null, obj ) )
		Next
	End Method


	Method Draw:Int(State:String = "", fromZ:Int=-1000, toZ:Int=-1000)
		'_lastDrawTick :+1
		'if _lastDrawTick >= 100000 then _lastDrawTick = 0

		currentState = State

		For Local obj:TGUIobject = EachIn List
			'all special objects get drawn separately
			If ListDragged.contains(obj) Then Continue
			If Not haveToHandleObject(obj,State,fromZ,toZ) Then Continue

			'skip invisible objects
			if not obj.IsVisible() then continue

			'avoid getting drawn multiple times
			'this can be overcome with a manual "obj.Draw()"-call
			'if obj._lastDrawTick = _lastDrawTick then continue
			'obj._lastDrawTick = _lastDrawTick

			'tint image if object is disabled
			If Not(obj._flags & GUI_OBJECT_ENABLED) Then SetAlpha 0.5*GetAlpha()
			obj.Draw()
			If Not(obj._flags & GUI_OBJECT_ENABLED) Then SetAlpha 2.0*GetAlpha()

			'fire event
			EventManager.triggerEvent( TEventSimple.Create( "guiobject.onDraw", Null, obj ) )
		Next

		'draw all dragged objects above normal objects...
		For Local obj:TGUIobject = EachIn listDraggedReversed
			If Not haveToHandleObject(obj,State,fromZ,toZ) Then Continue

			'avoid getting drawn multiple times
			'this can be overcome with a manual "obj.Draw()"-call
			'if obj._lastDrawTick = _lastDrawTick then continue
			'obj._lastDrawTick = _lastDrawTick

			obj.Draw()

			'fire event
			EventManager.triggerEvent( TEventSimple.Create( "guiobject.onDraw", Null, obj ) )
		Next
	End Method
End Type
Global GUIManager:TGUIManager = TGUIManager.GetInstance()




Type TGUIobject
	Field rect:TRectangle = new TRectangle.Init(-1,-1,-1,-1)
	Field positionBackup:TPoint = Null
	'storage for additional data
	Field data:TData = new TData
	Field scale:Float = 1.0
	Field alpha:Float = 1.0
	'where to attach the object
	Field handlePosition:TPoint	= new TPoint.Init(0, 0)
	'where to attach the content within the object
	Field contentPosition:TPoint = new TPoint.Init(0.5, 0.5)
	Field state:String = ""
	Field value:String = ""
	Field mouseIsClicked:TPoint	= Null			'null = not clicked
	Field mouseIsDown:TPoint = new TPoint.Init(-1,-1)
	Field mouseOver:Int	= 0						'could be done with TPoint
	Field children:TList = Null
	Field _id:Int
	Field _padding:TRectangle = null 'by default no padding
	Field _flags:Int = 0
	'status of the widget: eg. GUI_OBJECT_STATUS_APPEARANCE_CHANGED
	Field _status:int = 0
	'the font used to display text in the widget
	Field _font:TBitmapFont
	'time when item got dragged, maybe find a better name
	Field _timeDragged:Int = 0
	Field _parent:TGUIobject = Null
	'fuer welchen gamestate anzeigen
	Field _limitToState:String = ""
	'displacement of object when dragged (null = centered)
	Field handle:TPoint	= Null
	Field className:String			= ""
	'Field _lastDrawTick:int			= 0
	'Field _lastUpdateTick:int		= 0

	Global ghostAlpha:Float			= 0.5
	Global _focusedObject:TGUIObject= Null
	Global _lastID:Int
	Global _debugMode:Int			= False

	Const ALIGN_LEFT:Float		= 0
	Const ALIGN_CENTER:Float	= 0.5
	Const ALIGN_RIGHT:Float		= 1.0
	Const ALIGN_TOP:Float		= 0
	Const ALIGN_BOTTOM:Float	= 1.0


	Method New()
		_lastID:+1
		_id = _lastID
		scale	= GUIManager.globalScale
		className = TTypeId.ForObject(Self).Name()

		'default options
		setOption(GUI_OBJECT_VISIBLE, True)
		setOption(GUI_OBJECT_ENABLED, True)
		setOption(GUI_OBJECT_CLICKABLE, True)
	End Method


	Method CreateBase:TGUIobject(pos:TPoint, dimension:TPoint, limitState:String="")
		'create missing params
		If Not pos Then pos = new TPoint.Init(0,0)
		If Not dimension Then dimension = new TPoint.Init(-1,-1)

		rect.position.setXY(pos.x, pos.y)
		'resize widget, dimension of (-1,-1) is "auto dimension"
		Resize(dimension.x, dimension.y)

		_limitToState = limitState
	End Method


	Function SetTypeFont:Int(font:TBitmapFont)
		'implement in classes
	End Function


	'override in extended classes if wanted
	Function GetTypeFont:TBitmapFont()
		return Null
	End Function


	Method SetFont:Int(font:TBitmapFont)
		self._font = font
	End Method


	Method GetFont:TBitmapFont()
		if not _font
			if GetTypeFont() then return GetTypeFont()
			return GUIManager.GetDefaultFont()
		endif
		return _font
	End Method


	Method SetManaged(bool:Int)
		If bool
			If Not _flags & GUI_OBJECT_MANAGED Then GUIManager.add(Self)
		Else
			If _flags & GUI_OBJECT_MANAGED Then GUIManager.remove(Self)
		EndIf
	End Method


	Method AddEventListenerLink(link:TLink)
	End Method


	'cleanup function
	Method Remove:Int()
		'unlink all potential event listeners concerning that object
		EventManager.unregisterListenerByLimit(self,self)
'		For Local link:TLink = EachIn _registeredEventListener
'			link.Remove()
'		Next

		'maybe our parent takes care of us...
		If _parent Then _parent.RemoveChild(Self)

		'just in case we have a managed one
		'if _flags & GUI_OBJECT_MANAGED then
		GUIManager.remove(Self)

		Return True
	End Method


	Method GetClassName:String()
		Return TTypeId.ForObject(Self).Name()
'		return self.className
	End Method


	'convencience function to return the uppermost parent
	Method GetUppermostParent:TGUIObject()
		'also possible:
		'getParent("someunlikelyname")
		if _parent then return _parent.GetUppermostParent()
		return self
	End Method


	'returns the requested parent
	'if parentclassname is NOT found and <> "" you get the uppermost
	'parent returned
	Method GetParent:TGUIobject(parentClassName:String="", strictMode:Int=False)
		'if no special parent is requested, just return the direct parent or self
		If parentClassName=""
			if _parent then Return _parent
			return self
		endif

		If _parent
			If _parent.getClassName().toLower() = parentClassName.toLower() Then Return _parent
			Return _parent.getParent(parentClassName)
		EndIf
		'if no parent - we reached the top level and just return self
		'as the searched parent
		'exception is "strictMode" which forces exactly that wanted parent
		If strictMode
			Return Null
		Else
			Return Self
		EndIf
	End Method


	'default drop handler for all gui objects
	'by default they do nothing
	Method onDrop:Int(triggerEvent:TEventBase)
		If hasOption(GUI_OBJECT_ACCEPTS_DROP)
			triggerEvent.SetAccepted(True)
		Else
			Return False
		EndIf
	End Method



	'default single click handler for all gui objects
	'by default they do nothing
	'singleClick: waited long enough to see if there comes another mouse click
	Method onSingleClick:Int(triggerEvent:TEventBase)
		Return False
	End Method


	'default double click handler for all gui objects
	'by default they do nothing
	'doubleClick: waited long enough to see if there comes another mouse click
	Method onDoubleClick:Int(triggerEvent:TEventBase)
		Return False
	End Method
	

	'default hit handler for all gui objects
	'by default they do nothing
	'click: no wait: mouse button was down and is now up again
	Method onClick:Int(triggerEvent:TEventBase)
		Return False
	End Method


	Method AddChild:Int(child:TGUIobject)
		'remove child from a prior parent to avoid multiple references
		If child._parent Then child._parent.RemoveChild(child)

		child.setParent( Self )
		If Not children Then children = CreateList()
		If children.addLast(child) Then GUIManager.Remove(child)
		children.sort(True, TGUIManager.SortObjects)
	End Method


	Method RemoveChild:Int(child:TGUIobject)
		If Not children Then Return False
		If children.Remove(child) Then GUIManager.Add(child)
	End Method


	Method UpdateChildren:Int()
		If Not children Then Return False

		'update added elements
		For Local obj:TGUIobject = EachIn children.Reversed()

			'avoid getting updated multiple times
			'this can be overcome with a manual "obj.Update()"-call
			'if obj._lastUpdateTick = GUIManager._lastUpdateTick then continue
			'obj._lastUpdateTick = GUIManager._lastUpdateTick

			obj.update()
		Next
	End Method


	Method RestrictViewport:Int()
		Local screenRect:TRectangle = GetScreenRect()
		If screenRect
			GUIManager.RestrictViewport(screenRect.getX(),screenRect.getY(), screenRect.getW(),screenRect.getH())
			Return True
		Else
			Return False
		EndIf
	End Method


	Method ResetViewport()
		GUIManager.ResetViewport()
	End Method


	'sets the currently focused object
	Function setFocusedObject(obj:TGUIObject)
		'if there was an focused object -> inform about removal of focus
		If obj <> _focusedObject And _focusedObject Then _focusedObject.removeFocus()
		'set new focused object
		_focusedObject = obj
		'if there is a focused object now - inform about gain of focus
		If _focusedObject Then _focusedObject.setFocus()
	End Function


	'returns the currently focused object
	Function getFocusedObject:TGUIObject()
		Return _focusedObject
	End Function


	'returns whether the current object is the focused one
	Method hasFocus:Int()
		Return (Self = _focusedObject)
	End Method


	'object gains focus
	Method setFocus:Int()
		Return True
	End Method


	'object looses focus
	Method removeFocus:Int()
		Return True
	End Method


	Method GetValue:String()
		Return value
	End Method


	Method SetValue:Int(value:string)
		self.value = value
	End Method


	Method hasOption:Int(option:Int)
		Return _flags & option
	End Method


	Method setOption(option:Int, enable:Int=True)
		If enable
			_flags :| option
		Else
			_flags :& ~option
		EndIf
	End Method


	Method HasStatus:Int(statusCode:Int)
		Return _status & statusCode
	End Method


	Method SetStatus(statusCode:Int, enable:Int=True)
		If enable
			_status :| statusCode
		Else
			_status :& ~statusCode
		EndIf
	End Method


	Method IsAppearanceChanged:Int()
		Return _status & GUI_OBJECT_STATUS_APPEARANCE_CHANGED
	End Method


	Method SetAppearanceChanged:Int(bool:int)
		SetStatus(GUI_OBJECT_STATUS_APPEARANCE_CHANGED, bool)
	End Method

	'called when appearance changes - override in widgets to react
	'to it
	'do not call this directly, this is handled at the end of
	'each "update" call so multiple things can set "appearanceChanged"
	'but this function is called only "once"
	Method onStatusAppearanceChange:int()
		'
	End Method


	Method isDragable:Int()
		Return _flags & GUI_OBJECT_DRAGABLE
	End Method


	Method isDragged:Int()
		Return _flags & GUI_OBJECT_DRAGGED
	End Method


	Method IsVisible:Int()
		'i am invisible if my parent is not visible
'		if _parent and not _parent.IsVisible() then return FALSE
		Return _flags & GUI_OBJECT_VISIBLE
	End Method


	Method Show()
		_flags :| GUI_OBJECT_VISIBLE
	End Method


	Method Hide()
		_flags :& ~GUI_OBJECT_VISIBLE
	End Method


	Method enable()
		If Not hasOption(GUI_OBJECT_ENABLED)
			_flags :| GUI_OBJECT_ENABLED
			GUIManager.SortLists()
		EndIf
	End Method


	Method disable()
		If hasOption(GUI_OBJECT_ENABLED)
			_flags :& ~GUI_OBJECT_ENABLED
			GUIManager.SortLists()
		EndIf
	End Method


	Method Resize(w:Float=Null,h:Float=Null)
		If w Then rect.dimension.setX(w)
		If h Then rect.dimension.setY(h)
	End Method


	'set the anchor of the gui object
	'valid values are 0-1.0 (percentage)
	Method SetHandlePosition:Int(handleLeft:Float=0.0, handleTop:Float=0.0)
		handlePosition = new TPoint.init(handleLeft, handleTop)
	End Method


	'set the anchor of the gui objects content
	'valid values are 0-1.0 (percentage)
	Method SetContentPosition:Int(contentLeft:Float=0.0, contentTop:Float=0.0)
		contentPosition = new TPoint.Init(contentLeft, contentTop)
	End Method


	Method SetZIndex(zindex:Int)
		rect.position.z = zindex
		GUIManager.SortLists()
	End Method


	Method SetState(state:String="", forceSet:Int=False)
		If state <> "" Then state = "."+state
		If Self.state <> state Or forceSet
			'do other things (eg. events)
			Self.state = state
		EndIf
	End Method


	Method SetPadding:Int(top:Int,Left:Int,bottom:Int,Right:Int)
		if not _padding
			_padding = new TRectangle.Init(top, left, bottom, right)
		else
			_padding.setTLBR(top,Left,bottom,Right)
		endif
		resize()
	End Method


	Method GetPadding:TRectangle()
		if not _padding then _padding = new TRectangle.Init(0,0,0,0)
		Return _padding
	End Method


	Method drag:Int(coord:TPoint=Null)
		If Not isDragable() Or isDragged() Then Return False

		positionBackup = new TPoint.Init( GetScreenX(), GetScreenY() )


		Local event:TEventSimple = TEventSimple.Create("guiobject.onTryDrag", new TData.Add("coord", coord), self)
		EventManager.triggerEvent( event )
		'if there is no problem ...just start dropping
		If Not event.isVeto()
			'trigger an event immediately - if the event has a veto afterwards, do not drag!
			Local event:TEventSimple = TEventSimple.Create( "guiobject.onDrag", new TData.Add("coord", coord), Self )
			EventManager.triggerEvent( event )
			If event.isVeto() Then Return False

			'nobody said "no" to drag, so drag it
			GuiManager.AddDragged(Self)
			GUIManager.SortLists()

			'inform others - item finished dragging
			EventManager.triggerEvent(TEventSimple.Create("guiobject.onFinishDrag", new TData.Add("coord", coord), Self))

			Return True
		else
			Return FALSE
		endif
	End Method


	'forcefully drops an item back to the position when dragged
	Method dropBackToOrigin:Int()
		If Not positionBackup Then Return False
		drop(positionBackup, True)
		Return True
	End Method


	Method drop:Int(coord:TPoint=Null, force:Int=False)
		If Not isDragged() Then Return False

		If coord And coord.getX()=-1 Then coord = new TPoint.Init(MouseManager.x, MouseManager.y)


		Local event:TEventSimple = TEventSimple.Create("guiobject.onTryDrop", new TData.Add("coord", coord), self)
		EventManager.triggerEvent( event )
		'if there is no problem ...just start dropping
		If Not event.isVeto()

			'fire an event - if the event has a veto afterwards, do not drop!
			'exception is, if the action is forced
			Local event:TEventSimple = TEventSimple.Create("guiobject.onDrop", new TData.Add("coord", coord), Self)
			EventManager.triggerEvent( event )
			If Not force And event.isVeto() Then Return False

			'nobody said "no" to drop, so drop it
			GUIManager.RemoveDragged(Self)
			GUIManager.SortLists()

			'inform others - item finished dropping - Receiver of "event" may now be helding the guiobject dropped on
			EventManager.triggerEvent(TEventSimple.Create("guiobject.onFinishDrop", new TData.Add("coord", coord), Self, event.GetReceiver()))
			Return True
		else
			Return FALSE
		endif
	End Method


	Method setParent:Int(parent:TGUIobject)
		_parent = parent
	End Method


	'returns true if clicked
	Method isClicked:Int()
		If Not(_flags & GUI_OBJECT_ENABLED) Then mouseIsClicked = Null

		Return (mouseIsClicked<>Null)
	End Method


	Method SetLimitToState:Int(state:String)
		_limitToState = state
	End Method


	Method GetLimitToState:String()
		'if there is no limit set - ask parent if there is one
		If _limitToState="" And _parent Then Return _parent.GetLimitToState()

		Return _limitToState
	End Method


	Method GetScreenWidth:Float()
		Return rect.GetW()
	End Method


	Method GetScreenHeight:Float()
		Return rect.GetH()
	End Method


	Method GetScreenPos:TPoint()
		Return new TPoint.Init(GetScreenX(), GetScreenY())
	End Method


	'adds parent position
	Method GetScreenX:Float()
		If (_flags & GUI_OBJECT_DRAGGED) And Not(_flags & GUI_OBJECT_IGNORE_POSITIONMODIFIERS)
			'no manual setup of handle exists -> center the spot
			If Not handle
				Return MouseManager.x - GetScreenWidth()/2 + 5*GUIManager.GetDraggedNumber(Self)
			Else
				Return MouseManager.x - GetHandle().x + 5*GUIManager.GetDraggedNumber(Self)
			EndIf
		EndIf

		'only integrate parent if parent is set, or object not positioned "absolute"
		If _parent And Not(_flags & GUI_OBJECT_POSITIONABSOLUTE)
			'ignore parental padding or not
			If Not(_flags & GUI_OBJECT_IGNORE_PARENTPADDING)
				'instead of "ScreenX", we ask the parent where it wants the Content...
				Return _parent.GetContentScreenX() + rect.GetX()
			Else
				Return _parent.GetScreenX() + rect.GetX()
			EndIf
		Else
			Return rect.GetX()
		EndIf
	End Method


	Method GetScreenY:Float()
		If (_flags & GUI_OBJECT_DRAGGED) And Not(_flags & GUI_OBJECT_IGNORE_POSITIONMODIFIERS)
			'no manual setup of handle exists -> center the spot
			If Not handle
				Return MouseManager.y - getScreenHeight()/2 + 7*GUIManager.GetDraggedNumber(Self)
			Else
				Return MouseManager.y - GetHandle().y/2 + 7*GUIManager.GetDraggedNumber(Self)
			EndIf
		EndIf
		'only integrate parent if parent is set, or object not positioned "absolute"
		If _parent And Not(_flags & GUI_OBJECT_POSITIONABSOLUTE)
			'ignore parental padding or not
			If Not(_flags & GUI_OBJECT_IGNORE_PARENTPADDING)
				'instead of "ScreenY", we ask the parent where it wants the Content...
				Return _parent.GetContentScreenY() + rect.GetY()
			Else
				Return _parent.GetScreenY() + rect.GetY()
			EndIf
		Else
			Return rect.GetY()
		EndIf
	End Method


	'override this methods if the object something like
	'virtual size or "addtional padding"

	'at which x-coordinate has content/children to be drawn
	Method GetContentScreenX:Float()
		Return GetScreenX() + GetPadding().getLeft()
	End Method
	'at which y-coordinate has content/children to be drawn
	Method GetContentScreenY:Float()
		Return GetScreenY() + GetPadding().getTop()
	End Method
	'available width for content/children
	Method GetContentScreenWidth:Float()
		Return GetScreenWidth() - (GetPadding().getLeft() + GetPadding().getRight())
	End Method
	'available height for content/children
	Method GetContentScreenHeight:Float()
		Return GetScreenHeight() - (GetPadding().getTop() + GetPadding().getBottom())
	End Method


	Method SetHandle:Int(handle:TPoint)
		Self.handle = handle
	End Method


	Method GetHandle:TPoint()
		Return handle
	End Method


	Method GetRect:TRectangle()
		Return rect
	End Method


	Method getDimension:TPoint()
		Return rect.dimension
	End Method


	'get a rectangle describing the objects area on the screen
	Method GetScreenRect:TRectangle()
		'dragged items ignore parents but take care of mouse position...
		If isDragged() Then Return new TRectangle.Init(GetScreenX(), GetScreenY(), GetScreenWidth(), GetScreenHeight() )

		'no other limiting object - just return the object's area
		'(no move needed as it is already oriented to screen 0,0)
		If Not _parent
			If Not rect Then Print "NO SELF RECT"
			Return rect
		EndIf


		Local resultRect:TRectangle = _parent.GetScreenRect()
		'only try to intersect if the parent gaves back an intersection (or self if no parent)
		If resultRect
			'create a sourceRect which is a screen-rect (=visual!)
			Local sourceRect:TRectangle = new TRectangle.Init( ..
										    GetScreenX(),..
										    GetScreenY(),..
										    GetScreenWidth(),..
										    GetScreenHeight() )

			'get the intersecting rectangle
			'the x,y-values are local coordinates!
			resultRect = resultRect.intersectRect( sourceRect )
			If resultRect
				'move the resulting rect by coord to get a screen-Rect
				resultRect.position.setXY(..
					Max(resultRect.position.getX(),getScreenX()),..
					Max(resultRect.position.getY(),GetScreeny())..
				)
				Return resultRect
			EndIf
		EndIf
		Return new TRectangle.Init(0,0,-1,-1)
	End Method


	Method Draw() Abstract


	'used when an item is eg. dragged
	Method DrawGhost()
		Local oldAlpha:Float = GetAlpha()
		'by default a shaded version of the gui element is drawn at the original position
		SetOption(GUI_OBJECT_IGNORE_POSITIONMODIFIERS, True)
		SetOption(GUI_OBJECT_DRAWMODE_GHOST, True)
		SetAlpha ghostAlpha * oldAlpha
		Draw()
		SetAlpha oldAlpha
		SetOption(GUI_OBJECT_IGNORE_POSITIONMODIFIERS, False)
		SetOption(GUI_OBJECT_DRAWMODE_GHOST, False)
	End Method


	Method DrawChildren:Int()
		If Not children Then Return False

		'skip children if self not visible
		if not IsVisible() then return false

		'update added elements
		For Local obj:TGUIobject = EachIn children
			'before skipping a dragged one, we try to ask it as a ghost (at old position)
			If obj.isDragged() Then obj.drawGhost()
			'skip dragged ones - as we set them to managed by GUIManager for that time
			If obj.isDragged() Then Continue

			'skip invisible objects
			if not obj.IsVisible() then continue

			'avoid getting updated multiple times
			'this can be overcome with a manual "obj.Update()"-call
			'if obj._lastDrawTick = GUIManager._lastDrawTick then continue
			'obj._lastDrawTick = GUIManager._lastDrawTick


			'tint image if object is disabled
			If Not(obj._flags & GUI_OBJECT_ENABLED) Then SetAlpha 0.5*GetAlpha()
			obj.draw()
			'tint image if object is disabled
			If Not(obj._flags & GUI_OBJECT_ENABLED) Then SetAlpha 2.0*GetAlpha()
		Next
	End Method


	'returns whether a given coordinate is within the objects bounds
	'by default it just checks a simple rectangular bound
	Method containsXY:Int(x:Float,y:Float)
		'if not dragged ask parent first
		If Not isDragged() And _parent And Not _parent.containsXY(x,y) Then Return False
		Return GetScreenRect().containsXY(x,y)
	End Method


	Method Update:Int()
		'if appearance changed since last update tick: inform widget
		If isAppearanceChanged()
			onStatusAppearanceChange()
			SetAppearanceChanged(false)
		Endif

		'always be above parent
		If _parent And _parent.rect.position.z >= rect.position.z Then setZIndex(_parent.rect.position.z+10)

		If GUIManager._ignoreMouse then return FALSE

		'=== HANDLE MOUSE OVER ===

		'if nothing of the obj is visible or the mouse is not in
		'the visible part - reset the mouse states
		If Not containsXY(MouseManager.x, MouseManager.y)
			mouseIsDown		= Null
			mouseIsClicked	= Null
			mouseover		= 0
			setState("")

			'mouseclick somewhere - should deactivate active object
			'no need to use the cached mouseButtonDown[] as we want the
			'general information about a click
			If MOUSEMANAGER.isHit(1) And hasFocus() Then GUIManager.setFocus(Null)
		'mouse over object
		Else
			'inform others about a scroll with the mousewheel
			If GUIManager.UpdateState_mouseScrollwheelMovement <> 0
				Local event:TEventSimple = TEventSimple.Create("guiobject.OnScrollwheel", new TData.AddNumber("value", GUIManager.UpdateState_mouseScrollwheelMovement),Self)
				EventManager.triggerEvent(event)
				'a listener handles the scroll - so remove it for others
				If event.isAccepted()
					GUIManager.UpdateState_mouseScrollwheelMovement = 0
				EndIf
			EndIf
		EndIf


		'=== HANDLE MOUSE CLICKS / POSITION ===

		'skip non-clickable objects
		if not (_flags & GUI_OBJECT_CLICKABLE) then return FALSE
		'skip objects the mouse is not over.
		'ATTENTION: this differs to self.mouseOver (which is set later on)
		if not containsXY(MouseManager.x, MouseManager.y) then return FALSE


		'handle mouse clicks / button releases
		'only do something if
		'a) there is NO dragged object
		'b) we handle the dragged object
		'-> only react to dragged obj or all if none is dragged
		If Not GUIManager.GetDraggedCount() Or isDragged()

			'activate objects - or skip if if one gets active
			If GUIManager.UpdateState_mouseButtonDown[1] And _flags & GUI_OBJECT_ENABLED
				'create a new "event"
				If Not MouseIsDown
					'as soon as someone clicks on a object it is getting focused
					GUImanager.setFocus(Self)

					MouseIsDown = new TPoint.Init( MouseManager.x, MouseManager.y )
				EndIf

				'we found a gui element which can accept clicks
				'dont check further guiobjects for mousedown
				'ATTENTION: do not use MouseManager.ResetKey(1)
				'as this also removes "down" state
				GUIManager.UpdateState_mouseButtonDown[1] = False
				GUIManager.UpdateState_mouseButtonHit[1] = False
				'MOUSEMANAGER.ResetKey(1)
			EndIf

			If Not GUIManager.UpdateState_foundHoverObject And _flags & GUI_OBJECT_ENABLED

				'do not create "mouseover" for dragged objects
				If Not isDragged()
					'create events
					'onmouseenter
					If mouseover = 0
						EventManager.registerEvent( TEventSimple.Create( "guiobject.OnMouseEnter", new TData, Self ) )
						mouseover = 1
					EndIf
					'onmousemove
					EventManager.registerEvent( TEventSimple.Create("guiobject.OnMouseOver", new TData, Self ) )
					GUIManager.UpdateState_foundHoverObject = True
				EndIf

				'somone decided to say the button is pressed above the object
				If MouseIsDown
					setState("active")
					EventManager.registerEvent( TEventSimple.Create("guiobject.OnMouseDown", new TData.AddNumber("button", 1), Self ) )
				Else
					setState("hover")
				EndIf


				'inform others about a right guiobject click
				'we do use a "cached hit state" so we can reset it if
				'we found a one handling it
				If GUIManager.UpdateState_mouseButtonHit[2]
					Local clickEvent:TEventSimple = TEventSimple.Create("guiobject.OnClick", new TData.AddNumber("button",2), Self)
					OnClick(clickEvent)
					'fire onClickEvent
					EventManager.triggerEvent(clickEvent)

					'maybe change to "isAccepted" - but then each gui object
					'have to modify the event IF they accepted the click
					
					'reset Button
					GUIManager.UpdateState_mouseButtonHit[2] = False
				EndIf

				If Not GUIManager.UpdateState_foundHitObject And _flags & GUI_OBJECT_ENABLED
					If MOUSEMANAGER.IsClicked(1)
						'=== SET CLICKED VAR ====
						mouseIsClicked = new TPoint.Init( MouseManager.x, MouseManager.y)

						'=== SEND OUT CLICK EVENT ====
						'if recognized as "double click" no normal "onClick"
						'is emitted. Same for "single clicks".
						'this avoids sending "onClick" and after 100ms
						'again "onSingleClick" AND "onClick"
						Local clickEvent:TEventSimple
						If MOUSEMANAGER.IsDoubleClicked(1)
							clickEvent = TEventSimple.Create("guiobject.OnDoubleClick", new TData.AddNumber("button",1), Self)
							'let the object handle the click
							OnDoubleClick(clickEvent)
						ElseIf MOUSEMANAGER.IsSingleClicked(1)
							clickEvent = TEventSimple.Create("guiobject.OnSingleClick", new TData.AddNumber("button",1), Self)
							'let the object handle the click
							OnSingleClick(clickEvent)
						Else
							clickEvent = TEventSimple.Create("guiobject.OnClick", new TData.AddNumber("button",1), Self)
							'let the object handle the click
							OnClick(clickEvent)
						EndIf
						'fire onClickEvent
						EventManager.triggerEvent(clickEvent)

						'added for imagebutton and arrowbutton not being reset when mouse standing still
						MouseIsDown = Null
						'reset mouse button
						MOUSEMANAGER.ResetKey(1)

						'clicking on an object sets focus to it
						'so remove from old before
						If Not HasFocus() Then GUIManager.ResetFocus()

						GUIManager.UpdateState_foundHitObject = True
					EndIf
				EndIf
			EndIf
		EndIf
	End Method


'VERALTET !!!!!
REM
	'eg. for buttons/inputfields/dropdownbase...
	Method DrawBaseForm(identifier:String, x:Float, y:Float)
		SetScale scale, scale
		local spriteL:TSprite = TSprite(GetRegistry().Get(identifier+".L"))
		local spriteR:TSprite = TSprite(GetRegistry().Get(identifier+".R"))
		spriteL.Draw(x,y)
		TSprite(GetRegistry().Get(identifier+".M")).TileDrawHorizontal(x + spriteL.area.GetW()*scale, y, GetScreenWidth() - ( spriteL.area.GetW() + spriteR.area.GetW())*scale, scale)
		spriteR.Draw(x + GetScreenWidth(), y, -1, new TPoint.Init(ALIGN_LEFT, ALIGN_BOTTOM), scale)
		SetScale 1.0,1.0
	End Method
endrem

	Method DrawBaseFormText:Object(_value:String, x:Float, y:Float)
		Local col:TColor = TColor.Create(100,100,100)
		If mouseover Then col = TColor.Create(50,50,50)
		If Not(_flags & GUI_OBJECT_ENABLED) Then col = TColor.Create(150,150,150)

		Return GetFont().drawStyled(_value,x,y, col, 1, 1, 0.5)
	End Method


	'returns true if the conversion was successful
	Function ConvertKeystrokesToText:Int(value:String Var)
		Local shiftPressed:Int = False
		Local altGrPressed:Int = False
		?win32
		If KEYMANAGER.IsDown(160) Or KEYMANAGER.IsDown(161) Then shiftPressed = True
		If KEYMANAGER.IsDown(164) Or KEYMANAGER.IsDown(165) Then altGrPressed = True
		?
		?Not win32
		If KEYMANAGER.IsDown(160) Or KEYMANAGER.IsDown(161) Then shiftPressed = True
		If KEYMANAGER.IsDown(3) Then altGrPressed = True
		?

		Local charToAdd:String = ""
		For Local i:Int = 65 To 90
			charToAdd = ""
			If KEYWRAPPER.pressedKey(i)
				If i = 69 And altGrPressed Then charToAdd = "�"
				If i = 81 And altGrPressed Then charToAdd = "@"
				If shiftPressed Then charToAdd = Chr(i) Else charToAdd = Chr(i+32)
			EndIf
			value :+ charToAdd
		Next

		'num keys
		For Local i:Int = 96 To 105
			If KEYWRAPPER.pressedKey(i) Then charToAdd=i-96
		Next


		?Win32
        If KEYWRAPPER.pressedKey(186) Then If shiftPressed Then value:+ "�" Else value :+ "�"
        If KEYWRAPPER.pressedKey(192) Then If shiftPressed Then value:+ "�" Else value :+ "�"
        If KEYWRAPPER.pressedKey(222) Then If shiftPressed Then value:+ "�" Else value :+ "�"
		?Linux
        If KEYWRAPPER.pressedKey(252) Then If shiftPressed Then value:+ "�" Else value :+ "�"
        If KEYWRAPPER.pressedKey(246) Then If shiftPressed Then value:+ "�" Else value :+ "�"
        If KEYWRAPPER.pressedKey(163) Then If shiftPressed Then value:+ "�" Else value :+ "�"
		?
        If KEYWRAPPER.pressedKey(48) Then If shiftPressed Then value :+ "=" Else value :+ "0"
        If KEYWRAPPER.pressedKey(49) Then If shiftPressed Then value :+ "!" Else value :+ "1"
        If KEYWRAPPER.pressedKey(50) Then If shiftPressed Then value :+ Chr(34) Else value :+ "2"
        If KEYWRAPPER.pressedKey(51) Then If shiftPressed Then value :+ "�" Else value :+ "3"
        If KEYWRAPPER.pressedKey(52) Then If shiftPressed Then value :+ "$" Else value :+ "4"
        If KEYWRAPPER.pressedKey(53) Then If shiftPressed Then value :+ "%" Else value :+ "5"
        If KEYWRAPPER.pressedKey(54) Then If shiftPressed Then value :+ "&" Else value :+ "6"
        If KEYWRAPPER.pressedKey(55) Then If shiftPressed Then value :+ "/" Else value :+ "7"
        If KEYWRAPPER.pressedKey(56) Then If shiftPressed Then value :+ "(" Else value :+ "8"
        If KEYWRAPPER.pressedKey(57) Then If shiftPressed Then value :+ ")" Else value :+ "9"
        If KEYWRAPPER.pressedKey(223) Then If shiftPressed Then value :+ "?" Else value :+ "�"
        If KEYWRAPPER.pressedKey(81) And altGrPressed Then value :+ "@"
		?win32
        If KEYWRAPPER.pressedKey(219) And shiftPressed Then value :+ "?"
        If KEYWRAPPER.pressedKey(219) And altGrPressed Then value :+ "\"
        If KEYWRAPPER.pressedKey(219) And Not altGrPressed And Not shiftPressed Then value :+ "�"
        If KEYWRAPPER.pressedKey(221) Then If shiftPressed Then value :+ "`" Else value :+ "'"
        If KEYWRAPPER.pressedKey(226) Then If shiftPressed Then value :+ ">" Else value :+ "<"
		?linux
        If KEYWRAPPER.pressedKey(223) And shiftPressed Then value :+ "?"
        If KEYWRAPPER.pressedKey(223) And altGrPressed Then value :+ "\"
        If KEYWRAPPER.pressedKey(223) And Not altGrPressed And Not shiftPressed Then value :+ "�"
        If KEYWRAPPER.pressedKey(37) Then If shiftPressed Then value :+ "`" Else value :+ "'"
        If KEYWRAPPER.pressedKey(60) Then If shiftPressed Then value :+ ">" Else value :+ "<"
		?
        If KEYWRAPPER.pressedKey(43) And shiftPressed Then value :+ "*"
        If KEYWRAPPER.pressedKey(43) And altGrPressed Then value :+ "~~"
        If KEYWRAPPER.pressedKey(43) And Not altGrPressed And Not shiftPressed Then value :+ "+"
	    If KEYWRAPPER.pressedKey(60) Then If shiftPressed Then value :+ "�" Else value :+ "^"
	    If KEYWRAPPER.pressedKey(35) Then If shiftPressed Then value :+ "'" Else value :+ "#"
	    If KEYWRAPPER.pressedKey(188) Then If shiftPressed Then value :+ ";" Else value :+ ","
	    If KEYWRAPPER.pressedKey(189) Then If shiftPressed Then value :+ "_" Else value :+ "-"
	    If KEYWRAPPER.pressedKey(190) Then If shiftPressed Then value :+ ":" Else value :+ "."
	    'numblock
	    If KEYWRAPPER.pressedKey(106) Then value :+ "*"
	    If KEYWRAPPER.pressedKey(111) Then value :+ "/"
	    If KEYWRAPPER.pressedKey(109) Then value :+ "-"
	    If KEYWRAPPER.pressedKey(109) Then value :+ "-"
	    If KEYWRAPPER.pressedKey(110) Then value :+ ","
	    For Local i:Int = 0 To 9
			If KEYWRAPPER.pressedKey(96+i) Then value :+ i
		Next
		'space
	    If KEYWRAPPER.pressedKey(32) Then value :+ " "
	    'remove with backspace
        If KEYWRAPPER.pressedKey(KEY_BACKSPACE) Then value = value[..value.length -1]

		If KEYWRAPPER.pressedKey(KEY_ESCAPE) Then Return False
		Return True
	End Function
End Type