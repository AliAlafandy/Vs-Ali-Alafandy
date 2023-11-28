package options;

import flixel.FlxStrip;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import lime.utils.Assets;
import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.addons.transition.FlxTransitionableState;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import states.MainMenuState;
import states.TitleState;

class LanguageSelectorState extends MusicBeatState
{
	private var groupLanguage:FlxTypedGroup<Alphabet>;

	private static var currentlySelected:Int = 0;
	private var cameraGame:FlxCamera;
	public static var background:FlxSprite;
	public static var velocityBackground:FlxBackdrop;
	public var cameraFollow:FlxObject;
	public var cameraFollowPosition:FlxObject;
	public static var firstLaunch:Bool = false;
	
	var language:Array<Array<String>> = [];
	private var flagsArray:Array<AttachedSprite> = [];

	override function create()
	{
		FlxG.sound.playMusic(Paths.music('offsetSong'));
        Paths.clearStoredMemory();
		var languagesLoaded:Map<String, Bool> = new Map();
	
		#if MODS_ALLOWED
		var directories:Array<String> = [
			Paths.getPreloadPath('languages/'), Paths.mods('languages/'), Paths.mods(Paths.currentModDirectory + '/languages/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/languages/'));
		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(SUtil.getPath() + directory))
			{
				for (file in FileSystem.readDirectory(SUtil.getPath() + directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var languageToCheck:String = file.substr(0, file.length - 5);
						if (!languagesLoaded.exists(languageToCheck))
						{
							var languagePath = Paths.getTextFromFile('languages/' + languageToCheck + '.json');
					
							var languageJson = cast Json.parse(languagePath);
					
							var languageName = languageJson.languageName;

							language.push([languageToCheck, languageName]);
							languagesLoaded.set(languageToCheck, true);
						}
					}
				}
			}
		}
		#else
		{
			var fullText:String = Assets.getText(Paths.txt(SUtil.getPath() + 'languagesList'));
	
			var firstArray:Array<String> = fullText.split('\n');
	
			for (i in firstArray)
			{
				var languagePath = Paths.getTextFromFile(SUtil.getPath() + 'languages/' + i + '.json');
		
				var languageJson = cast Json.parse(languagePath);
		
				var languageName = languageJson.languageName;
				language.push([i, languageName]);
			}
		#end

		#if desktop
		DiscordClient.changePresence("In the Language Selector Menu", null);
		#end


		cameraGame = new FlxCamera();
		FlxG.cameras.reset(cameraGame);
		FlxG.cameras.setDefaultDrawTarget(cameraGame, true);

		background = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		switch (ClientPrefs.themes) {
			case 'Psych Engine':
				background.color = 0xFF009900;
			
			default:
				background.color = 0xFF800080;
		}
		background.updateHitbox();
		background.screenCenter();
		background.antialiasing = ClientPrefs.globalAntialiasing;
		add(background);

		velocityBackground = new FlxBackdrop(FlxGridOverlay.createGrid(30, 30, 60, 60, true, 0x3BAAAAAA, 0x0), XY);
		velocityBackground.velocity.set(FlxG.random.bool(50) ? 90 : -90, FlxG.random.bool(50) ? 90 : -90);
		velocityBackground.visible = ClientPrefs.velocityBackground;
		velocityBackground.antialiasing = ClientPrefs.globalAntialiasing;
		add(velocityBackground);

		groupLanguage = new FlxTypedGroup<Alphabet>();
		add(groupLanguage);

		if (language.length == 1) {
			language.push(['null', 'Nothing in /mods']);
		}

		for (i in 0...language.length)
		{
			var languageText:Alphabet = new Alphabet(320, 320, language[i][1], true);
			languageText.isMenuItem = true;
			languageText.targetY = i;
			languageText.ID = i;
			groupLanguage.add(languageText);
			languageText.snapToPosition();

			var flags:AttachedSprite = new AttachedSprite();
			flags.frames = Paths.getSparrowAtlas('languages/' + language[i][0]);
			flags.animation.addByPrefix('idle', language[i][0], 24);
			flags.animation.play('idle');
			flags.xAdd = -flags.width - 10;
			flags.sprTracker = languageText;

			// using a FlxGroup is too much fuss!
			flagsArray.push(flags);
			add(flags);
		}

		Paths.clearUnusedMemory();

		var langMenu:String;
		if (firstLaunch)
			langMenu = 'Language';
		else
			langMenu = LanguageHandler.language;

		var titleText:Alphabet = new Alphabet(0, 0, langMenu, true);
		titleText.x += 60;
		titleText.y += 40;
		titleText.alpha = 0.4;
		add(titleText);

		currentlySelected = 0;
		changeSelection();

		#if android
		addVirtualPad(UP_DOWN, A_B);
		#end

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.camera.shake(0.55, 0.5);
		}

		if (controls.ACCEPT)
		{	
			if (!firstLaunch) {
				firstLaunch = true; // Is required for Android because the basic bool is setuped to be false. Silly TomyGamy
				ClientPrefs.language = language[currentlySelected][0];
				ClientPrefs.saveSettings();
				LanguageHandler.regenerateLang(language[currentlySelected][0]);
				MusicBeatState.switchState(new TitleState());
			}
		}

		var languageTarget:Int = 0;
		for (item in groupLanguage.members) {
			item.targetY = languageTarget - currentlySelected;
			languageTarget++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0) {
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}

	function changeSelection(change:Int = 0)
	{
		currentlySelected += change;
		if (currentlySelected < 0)
			currentlySelected = language.length - 1;
		if (currentlySelected >= language.length)
			currentlySelected = 0;

		var alphabetValue:Int = 0;

		for (item in groupLanguage.members)
		{
			item.targetY = alphabetValue - currentlySelected;
			alphabetValue++;

			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}
