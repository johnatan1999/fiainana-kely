extends SceneTree

## Villagers, from the tables below:
## 1. builds entities/villager/villager.tscn (body, VillagerVisual, speech
##    bubble);
## 2. writes data/villagers/<id>.tres for each villager - only the missing
##    ones: once written, a villager is edited in the inspector (look,
##    routine, greetings) and this tool leaves it alone (delete the file to
##    have it rewritten from the table, or pass "-- --routines" to rewrite
##    every villager's routine from the table, the rest untouched);
## 3. rebuilds, in each zone of ZONES, the VillagerRoads (roads + spots),
##    the neighbours' paddies (VillagePaddy) and the Villagers nodes - one
##    Villager per villager whose day passes through that zone - leaving the
##    rest of the scene alone.
## Run with --editor (re-saving a scene outside the editor writes every
## exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/place_villagers.gd
## Fine-tuning roads and spots in the editor afterwards is fine - but
## rerunning this resets them to the tables.

const VILLAGER_SCENE := "res://entities/villager/villager.tscn"
const INTERACTABLE := "res://components/interaction/interactable_component.tscn"
const DATA_DIR := "res://data/villagers/"
const LAYERS := "res://assets/sprites/characters/villager/example_%s.png"
const TILE := 48
## Weekdays for the routine entries' optional 7th element (none = every day).
## An optional 8th element sets the step's story condition: {"only_if": name}
## or {"unless": name} (VillagerStop).
const SCHOOL_DAYS := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
const WEEKEND := ["SATURDAY", "SUNDAY"]
## The weekly market in the market town (GameClock.MARKET_DAY), and the other days.
const MARKET := ["FRIDAY"]
const NOT_MARKET := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "SATURDAY", "SUNDAY"]
## The Sunday cockfight tournament in the market town
## (FarmSimulation.COCKFIGHT_DAY), and the other days.
const SUNDAY := ["SUNDAY"]
const NOT_SUNDAY := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

## World zone id -> its scene, the spots (Marker2Ds under
## VillagerRoads/Spots), the roads along its dirt paths (one Line2D each; a
## point shared by two roads, within VillagerRoads.MERGE_DISTANCE, joins
## them), its neighbours' paddies [ground cell of the top-left corner,
## size in cells] and the trees to take out to make room for them (by
## name, under Trees). "Vers_<zone>" spots are the ways to the other zones.
const ZONES := {
	"village": {
		"scene": "res://world/areas/exterior/player_village.tscn",
		"spots": {
			"House_West": Vector2(274, 1108),
			"House_East": Vector2(1986, 1025),
			"House_South": Vector2(1584, 1440),
			"Market": Vector2(1290, 850),
			"Square": Vector2(950, 600),
			"Bench_East": Vector2(1850, 1040),
			"To_rice_fields": Vector2(1505, 30),
			# The village centre (tools/place_village_center.gd).
			"School": Vector2(936, 535),
			"Pitch": Vector2(875, 760),
			"WaterPoint": Vector2(575, 905),
			"Eatery": Vector2(775, 1300),
			"Grocery": Vector2(1150, 1035),
			"To_farm": Vector2(15, 505),
			"To_market_town": Vector2(1585, 1620),
		},
		"roads": {
			"Road_West": [Vector2(274, 1108), Vector2(450, 1100), Vector2(480, 900), Vector2(480, 620), Vector2(560, 560)],
			"Road_Square": [Vector2(560, 560), Vector2(950, 575), Vector2(1150, 555), Vector2(1300, 575), Vector2(1460, 640), Vector2(1520, 720)],
			"Road_North": [Vector2(1520, 720), Vector2(1530, 450), Vector2(1510, 200), Vector2(1505, 30)],
			"Road_Market": [Vector2(1460, 640), Vector2(1430, 780), Vector2(1290, 850)],
			"Road_East": [Vector2(1520, 720), Vector2(1650, 880), Vector2(1760, 1030), Vector2(1850, 1030), Vector2(1986, 1025)],
			"Road_South": [Vector2(1430, 780), Vector2(1450, 960), Vector2(1370, 1150), Vector2(1370, 1440), Vector2(1584, 1440)],
			"Road_Eatery": [Vector2(450, 1100), Vector2(560, 1250), Vector2(775, 1300)],
			"Road_Grocery": [Vector2(1290, 850), Vector2(1180, 1035)],
			"Road_Farm": [Vector2(560, 560), Vector2(300, 515), Vector2(15, 505)],
			"Road_MarketTown": [Vector2(1370, 1440), Vector2(1500, 1520), Vector2(1585, 1620)],
		},
		"paddies": [],
		"remove_trees": [],
	},
	"farm": {
		"scene": "res://world/areas/exterior/player_farm.tscn",
		"spots": {
			"House": Vector2(1022, 500),
			"To_village": Vector2(1430, 560),
			"Mortar": Vector2(875, 560),
			"Kitchen": Vector2(1190, 560),
			"Woodpile": Vector2(1265, 565),
			"Laundry": Vector2(1290, 690),
			"Coop": Vector2(420, 650),
			"Orchard": Vector2(360, 1360),
		},
		"roads": {
			"Road_Yard": [Vector2(1430, 560), Vector2(1265, 565), Vector2(1190, 560), Vector2(1022, 540),
				Vector2(875, 560), Vector2(560, 555), Vector2(470, 560), Vector2(420, 650)],
			"Road_House": [Vector2(1022, 540), Vector2(1022, 500)],
			"Road_Laundry": [Vector2(1265, 565), Vector2(1290, 690)],
			"Road_Orchard": [Vector2(470, 560), Vector2(460, 1100), Vector2(360, 1360)],
		},
		"paddies": [],
		"remove_trees": [],
	},
	"market_town": {
		"scene": "res://world/areas/exterior/market_town.tscn",
		"spots": {
			"To_village": Vector2(1056, 20),
			"Bridge": Vector2(1056, 500),
			"WashingStones": Vector2(700, 505),
			"MarketSquare": Vector2(1056, 950),
			# Behind the stalls (tools/build_market_town.gd).
			"Market_Collector": Vector2(1290, 760),
			"Market_Vegetables_1": Vector2(620, 760),
			"Market_Cloth_1": Vector2(830, 760),
			"Market_Vegetables_3": Vector2(1500, 760),
			"Taxi": Vector2(1150, 1480),
			"House_Rabe": Vector2(1957, 883),
			"House_Lalao": Vector2(278, 1350),
			# The zebu market, north of the river (tools/place_zebu_herds.gd).
			"ZebuMarket": Vector2(255, 285),
			"House_Ratsimba": Vector2(1876, 1362),
			# Around the cockfight ring (tools/place_cockfight.gd).
			"Cockfight_South": Vector2(1380, 578),
			"Cockfight_West": Vector2(1255, 508),
			"Cockfight_East": Vector2(1505, 508),
		},
		"roads": {
			"Road_North": [Vector2(1056, 20), Vector2(1056, 260), Vector2(1056, 500), Vector2(1056, 700),
				Vector2(1056, 950), Vector2(1056, 1380), Vector2(1056, 1480), Vector2(1150, 1480)],
			"Road_Zebu": [Vector2(1056, 260), Vector2(640, 285), Vector2(255, 285)],
			"Road_Ratsimba": [Vector2(1056, 1380), Vector2(1600, 1390), Vector2(1876, 1362)],
			"Road_WashingStones": [Vector2(1056, 500), Vector2(900, 500), Vector2(700, 505)],
			"Road_Cockfight": [Vector2(1056, 500), Vector2(1255, 508), Vector2(1380, 578), Vector2(1505, 508)],
			"Road_Market_West": [Vector2(1056, 700), Vector2(830, 760), Vector2(620, 760)],
			"Road_Market_East": [Vector2(1056, 700), Vector2(1290, 760), Vector2(1500, 760)],
			"Road_Rabe": [Vector2(1056, 950), Vector2(1600, 960), Vector2(1957, 883)],
			"Road_Lalao": [Vector2(1056, 950), Vector2(480, 960), Vector2(278, 1350)],
		},
		"paddies": [],
		"remove_trees": [],
	},
	"rice_fields": {
		"scene": "res://world/areas/exterior/rice_fields.tscn",
		"spots": {
			"To_village": Vector2(960, 1320),
			"Hut": Vector2(1135, 1125),
			"NeighbourPaddy_1": Vector2(1310, 1115),
			"NeighbourPaddy_2": Vector2(1420, 1205),
		},
		"roads": {
			"Road_Village": [Vector2(960, 1320), Vector2(960, 1180), Vector2(1135, 1150), Vector2(1235, 1150)],
		},
		# Right of the hut, seen from the road. The south hedge's west trees
		# would hide it under their foliage.
		"paddies": [[Vector2i(26, 22), Vector2i(5, 4)]],
		"remove_trees": ["Hedge_South_3_01", "Hedge_South_3_02", "Hedge_South_3_03"],
	},
}

## id -> name, role, home (a spot of home_zone - the village unless set;
## "family": the player's own, on the farm), size, skin, layers [sheet, color],
## routine [hour, minute, zone ("" = home), spot, activity, rain_proof],
## greetings, orders [item, min, max, unit reward, days, request line (%d =
## the quantity), thanks line] - see OrderTemplate - and friendship gifts
## [hearts, item, quantity, line] - see FriendshipReward.
const VILLAGERS := {
	"rakoto": {
		"name": "Rakoto", "role": "Fermier, il cultive la rizière des voisins", "home": "House_West", "size": 1.0, "skin": Color(0.45, 0.29, 0.19),
		"layers": [["trousers", Color(0.45, 0.35, 0.25)], ["shirt", Color(0.92, 0.9, 0.82)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.86, 0.74, 0.46)]],
		"routine": [
			[6, 30, "rice_fields", "NeighbourPaddy_1", "WORK", true],
			[12, 0, "rice_fields", "Hut", "STAND", true],
			[13, 0, "rice_fields", "NeighbourPaddy_1", "WORK", true, NOT_SUNDAY],
			[13, 30, "market_town", "Cockfight_South", "STAND", true, SUNDAY],
			[16, 0, "", "Eatery", "STAND", false, NOT_SUNDAY],
			[18, 0, "", "House_West", "INSIDE", true],
		],
		"greetings": ["Bonjour ! Le riz pousse bien cette année.", "Les rizières ont besoin de bras, tu sais."],
		"orders": [
			["rice", 5, 8, 5500, 14, "Ma rizière ne suffira pas cette saison. Tu me vendrais %d mesures de riz ?", "Misaotra ! Avec ça, la famille mangera jusqu'à la récolte."],
			["cassava", 6, 8, 1400, 10, "Il me faut %d racines de manioc pour la famille. Tu peux ?", "Merci, voisin !"],
			["corn", 6, 8, 1600, 7, "Tu aurais %d épis de maïs pour moi ?", "Parfait, merci !"],
		],
		"gifts": [
			[2, "rice_seed", 6, "Tiens, du riz de semence de ma récolte. Il pousse bien par ici."],
			[4, "rice_seed", 12, "Tu es comme de la famille. Prends ce riz de semence, tu en feras bon usage."],
		],
	},
	"ravao": {
		"name": "Ravao", "role": "Marchande, elle tient l'étal du marché", "home": "House_East", "size": 1.0, "skin": Color(0.55, 0.36, 0.24),
		"layers": [["skirt", Color(0.75, 0.3, 0.25)], ["shirt", Color(0.95, 0.85, 0.55)], ["hair_bun", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[6, 30, "market_town", "Market_Cloth_1", "STAND", true, MARKET],
			[7, 0, "", "Market", "STAND", true, NOT_MARKET],
			[12, 0, "", "Bench_East", "STAND", false, NOT_MARKET],
			[13, 30, "", "Market", "STAND", true, NOT_MARKET],
			[15, 30, "", "Bench_East", "STAND", false, MARKET],
			[17, 30, "", "House_East", "INSIDE", true],
		],
		"greetings": ["Des légumes frais au marché !", "Bonjour ! Tu passes au marché ?",
			"Le zoma, je vends mes lambas au tsena du bourg."],
		"orders": [
			["cassava", 4, 6, 1500, 10, "Mes clients réclament du manioc. Il m'en faudrait %d racines.", "Merci ! Mes clients vont être contents."],
			["corn", 5, 8, 1700, 7, "Le maïs grillé se vend bien en ce moment. Tu m'apportes %d épis ?", "Ils sont beaux ! Merci."],
			["tomato", 3, 5, 6500, 9, "Il me faut %d tomates pour la sauce du marché. Tu en auras ?", "Merci, elles sont bien mûres !"],
			["sweet_potato", 4, 6, 2000, 8, "Les patates douces partent vite. J'en voudrais %d.", "Merci ! Je les mets tout de suite à l'étal."],
			["potato", 3, 5, 7000, 12, "Tu pourrais me vendre %d pommes de terre ?", "Merci beaucoup !"],
		],
		"gifts": [
			[2, "tomato_seed", 5, "Des graines de tomate de mon jardin. Elles se vendent bien au marché !"],
			[4, "potato_seed", 5, "Des plants de pomme de terre, pour la saison sèche. Merci pour tout !"],
		],
	},
	"neny_soa": {
		"name": "Neny Soa", "role": "La grand-mère du village", "home": "House_South", "size": 0.95, "skin": Color(0.5, 0.33, 0.22),
		"layers": [["skirt", Color(0.3, 0.35, 0.55)], ["shirt", Color(0.85, 0.85, 0.85)], ["hair_bun", Color(0.75, 0.75, 0.75)]],
		"routine": [
			[7, 0, "", "WaterPoint", "STAND", false],
			[8, 30, "", "Square", "WANDER", false],
			[11, 0, "", "House_South", "INSIDE", true],
			[15, 0, "", "Bench_East", "STAND", false],
			[17, 30, "", "House_South", "INSIDE", true],
		],
		"greetings": ["Ah, mon enfant ! Tu travailles bien.", "Quand j'étais jeune, tout ce champ était à mon père."],
		"orders": [
			["mango", 3, 5, 1200, 4, "Mes petits-enfants adorent les mangues. Tu m'en apportes %d ?", "Que Dieu te bénisse, mon enfant."],
			["egg", 2, 4, 1000, 4, "J'aimerais %d œufs pour faire un gâteau.", "Merci, mon enfant. Passe goûter le gâteau !"],
			["bean", 4, 6, 3500, 9, "Je prépare des haricots pour la famille. Il m'en faudrait %d.", "Merci, tu es bien serviable."],
			["groundnut", 3, 5, 4000, 10, "Avec %d arachides, je ferais de la pâte d'arachide !", "Merci, mon enfant !"],
			["cassava", 3, 4, 1500, 10, "Un peu de manioc pour le repas : %d racines, ça m'irait.", "Merci, mon enfant."],
		],
		"gifts": [
			[2, "food_vary_amin_anana", 1, "Je t'ai préparé du riz aux brèdes, mon enfant."],
			[4, "food_vary_sy_laoka", 2, "Viens manger à la maison quand tu veux. En attendant, prends ça."],
		],
	},
	"koto": {
		"name": "Koto", "role": "Un enfant du village, toujours à jouer", "home": "House_South", "size": 0.8, "skin": Color(0.5, 0.33, 0.22),
		"layers": [["shorts", Color(0.25, 0.35, 0.6)], ["shirt", Color(0.85, 0.3, 0.25)], ["hair", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[7, 30, "", "School", "STAND", true, SCHOOL_DAYS],
			[8, 30, "", "Pitch", "WANDER", false, WEEKEND],
			[12, 0, "", "House_South", "INSIDE", true],
			[14, 0, "", "Market", "WANDER", false],
			[14, 0, "market_town", "Cockfight_South", "STAND", true, SUNDAY],
			[16, 30, "", "Pitch", "WANDER", false],
			[18, 30, "", "House_South", "INSIDE", true],
		],
		"greetings": ["Salut ! On joue ?", "J'ai vu un caméléon près du manguier !"],
		"orders": [
			["mango", 1, 2, 1500, 3, "Tu as des mangues ? J'en voudrais %d, s'il te plaît !", "Youpi ! Merci !"],
			["corn", 2, 3, 2000, 6, "Je veux faire griller %d épis de maïs avec mes copains !", "Trop bien, merci !"],
			["egg", 1, 2, 1200, 3, "Maman veut %d œufs. Tu en as ?", "Merci ! Maman va être contente."],
		],
		"gifts": [
			[2, "mango", 2, "Je t'ai gardé des mangues ! Les plus belles !"],
			[4, "groundnut_seed", 4, "J'ai trouvé des graines d'arachide. C'est pour toi !"],
		],
	},
	"naivo": {
		"name": "Naivo", "role": "Fermier, il cultive la rizière des voisins", "home": "House_East", "size": 1.05, "skin": Color(0.62, 0.42, 0.28),
		"layers": [["shorts", Color(0.3, 0.4, 0.3)], ["shirt", Color(0.6, 0.45, 0.3)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.8, 0.68, 0.42)]],
		"routine": [
			[6, 15, "rice_fields", "NeighbourPaddy_2", "WORK", true],
			[11, 30, "rice_fields", "Hut", "STAND", true],
			[12, 30, "rice_fields", "NeighbourPaddy_2", "WORK", true, NOT_SUNDAY],
			[13, 30, "market_town", "Cockfight_West", "STAND", true, SUNDAY],
			[15, 30, "", "Grocery", "STAND", false, NOT_SUNDAY],
			[17, 0, "", "Eatery", "STAND", false],
			[18, 15, "", "House_East", "INSIDE", true],
		],
		"greetings": ["Belle journée pour travailler la terre.", "Bonjour, voisin !", "Le repiquage, ça casse le dos !"],
		"orders": [
			["sweet_potato", 5, 7, 1900, 8, "Il me faudrait %d patates douces pour la saison sèche.", "Merci, voisin !"],
			["groundnut", 4, 6, 3900, 10, "Tu cultives des arachides ? J'en voudrais %d.", "Parfait, merci !"],
			["bean", 4, 6, 3400, 9, "J'ai besoin de %d haricots pour ma femme.", "Merci, elle sera contente !"],
			["corn", 5, 7, 1600, 7, "%d épis de maïs, tu peux m'en trouver ?", "Merci beaucoup !"],
		],
		"gifts": [
			[2, "groundnut_seed", 5, "Des graines d'arachide, pour la saison sèche."],
			[4, "sweet_potato_seed", 6, "Des boutures de patate douce. Tu es un bon voisin."],
		],
	},
	# The player's family, on the farm.
	"mother": {
		"name": "Neny", "role": "Ta mère", "home": "House", "home_zone": "farm", "family": true,
		"size": 1.0, "skin": Color(0.5, 0.33, 0.22),
		"layers": [["skirt", Color(0.25, 0.45, 0.35)], ["shirt", Color(0.95, 0.92, 0.8)], ["hair_bun", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[6, 0, "", "Mortar", "STAND", true],
			[9, 0, "village", "WaterPoint", "STAND", false],
			[10, 30, "", "Laundry", "STAND", false],
			[12, 0, "", "Kitchen", "STAND", true],
			[14, 0, "", "Coop", "WANDER", false],
			[16, 0, "", "Mortar", "STAND", true],
			[18, 0, "", "House", "INSIDE", true],
		],
		"greetings": [
			"Arrose tes cultures chaque jour, sauf quand il pleut.",
			"Les graines s'achètent au marché du village, à l'est.",
			"Les villageois te passeront des commandes : regarde au-dessus de leur tête.",
			"Les poules ont besoin d'eau et de grain chaque jour.",
			"Ne te couche pas trop tard, le travail commence tôt !",
		],
	},
	"father": {
		"name": "Dada", "role": "Ton père", "home": "House", "home_zone": "farm", "family": true,
		"size": 1.05, "skin": Color(0.45, 0.29, 0.19),
		"layers": [["trousers", Color(0.35, 0.32, 0.28)], ["shirt", Color(0.75, 0.6, 0.4)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.84, 0.72, 0.45)]],
		"routine": [
			[6, 30, "", "Orchard", "WORK", true],
			[11, 30, "", "House", "INSIDE", true],
			[13, 30, "", "Woodpile", "WORK", false],
			[16, 0, "village", "Eatery", "STAND", false],
			[18, 30, "", "House", "INSIDE", true],
		],
		"greetings": [
			"Le manioc pousse en toute saison : c'est une valeur sûre.",
			"En Asara, plante du riz et du maïs ; en Asotry, des patates douces et des arachides.",
			"Garde un peu d'argent pour agrandir nos terres.",
			"Aide les voisins à la moisson, ils te le rendront.",
		],
	},
	"fara": {
		"name": "Fara", "role": "Ta petite sœur", "home": "House", "home_zone": "farm", "family": true,
		"size": 0.75, "skin": Color(0.5, 0.33, 0.22),
		"layers": [["skirt", Color(0.85, 0.4, 0.55)], ["shirt", Color(0.98, 0.95, 0.9)], ["hair", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[7, 15, "village", "School", "STAND", true, SCHOOL_DAYS, {"unless": "school_fees_overdue"}],
			# Sent home from school (fees unpaid): helps Neny at the mortar.
			[7, 15, "", "Mortar", "WORK", true, SCHOOL_DAYS, {"only_if": "school_fees_overdue"}],
			[9, 0, "", "Coop", "WANDER", false, WEEKEND],
			[12, 15, "", "Coop", "WANDER", false],
			[14, 30, "", "House", "INSIDE", true],
			[16, 0, "village", "Pitch", "WANDER", false],
			[17, 45, "", "House", "INSIDE", true],
		],
		"greetings": [
			"Tu joues avec moi ?",
			"Koto est trop fort au foot !",
			"Les poules m'ont suivie jusqu'au poulailler !",
			"Maman dit que tu travailles bien.",
		],
	},
	# The market town's merchants.
	"rabe": {
		"name": "Rabe", "role": "Collecteur, il achète vanille et girofle au tsena du bourg",
		"home": "House_Rabe", "home_zone": "market_town", "size": 1.05, "skin": Color(0.48, 0.31, 0.2),
		"layers": [["trousers", Color(0.25, 0.25, 0.3)], ["shirt", Color(0.92, 0.92, 0.95)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.35, 0.3, 0.25)]],
		"routine": [
			[6, 0, "", "Market_Collector", "STAND", true, MARKET],
			[8, 30, "", "Taxi", "STAND", false, NOT_MARKET],
			[12, 0, "", "House_Rabe", "INSIDE", true, NOT_MARKET],
			[14, 0, "", "MarketSquare", "WANDER", false, NOT_MARKET],
			[14, 0, "", "Cockfight_East", "STAND", true, SUNDAY],
			[17, 0, "", "MarketSquare", "WANDER", false, MARKET],
			[18, 0, "", "House_Rabe", "INSIDE", true],
		],
		"greetings": [
			"Vanille, girofle, café, litchis : le zoma, je t'achète tout !",
			"Le tsena n'ouvre que le zoma. Reviens avec ta récolte !",
			"La vanille met longtemps à pousser, mais rien ne paie mieux.",
			"Le taxi-brousse emporte nos sacs jusqu'à la ville.",
		],
		"orders": [
			["coffee", 3, 5, 16000, 12, "Un client de la ville veut du café. Il m'en faudrait %d.", "Beau café ! Le client sera content."],
			["clove", 2, 4, 20000, 14, "Je monte un sac de girofle : tu m'en apportes %d ?", "Ça sent bon le girofle ! Merci."],
			["litchi", 4, 6, 26000, 14, "Les litchis partent par camion pour les fêtes. %d, tu les as ?", "Parfait, ils sont bien rouges !"],
			["vanilla", 1, 2, 40000, 20, "Il me manque %d gousses de vanille pour un lot. Tu en as ?", "De la belle vanille ! Tu as la main verte."],
		],
		"gifts": [
			[2, "coffee_seed", 2, "Des graines de café. Plante-les, je te rachèterai la récolte."],
			[4, "vanilla_seed", 2, "De la vanille. Elle demande de la patience, mais c'est de l'or vert."],
		],
	},
	"lalao": {
		"name": "Lalao", "role": "Marchande de légumes au tsena du bourg",
		"home": "House_Lalao", "home_zone": "market_town", "size": 0.95, "skin": Color(0.52, 0.34, 0.22),
		"layers": [["skirt", Color(0.55, 0.3, 0.55)], ["shirt", Color(0.95, 0.9, 0.75)], ["hair_bun", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[6, 0, "", "Market_Vegetables_1", "STAND", true, MARKET],
			[7, 30, "", "WashingStones", "STAND", false, NOT_MARKET],
			[11, 0, "", "House_Lalao", "INSIDE", true, NOT_MARKET],
			[15, 0, "", "Bridge", "STAND", false, NOT_MARKET],
			[17, 0, "", "House_Lalao", "INSIDE", true],
		],
		"greetings": [
			"Tomates, haricots, brèdes ! Viens voir mon étal le zoma.",
			"Le zoma, tout le monde descend au bourg.",
			"Je lave le linge à la rivière quand il n'y a pas marché.",
		],
		"orders": [
			["tomato", 4, 6, 6500, 9, "Il me faut %d tomates pour l'étal du zoma.", "Merci ! Elles partiront vite."],
			["bean", 4, 6, 3500, 9, "Tu m'apportes %d haricots pour le zoma ?", "Merci beaucoup !"],
			["groundnut", 3, 5, 4000, 10, "Les arachides se vendent bien au bourg : %d, ça te va ?", "Merci, à zoma !"],
		],
		"gifts": [
			[2, "bean_seed", 6, "Des haricots de ma récolte, pour ta ferme."],
			[4, "clove_seed", 2, "Mon frère cultive le girofle sur la côte. Tiens, quelques graines."],
		],
	},
	"ratsimba": {
		"name": "Ratsimba", "role": "Marchand de zébus, au tsena omby du bourg",
		"home": "House_Ratsimba", "home_zone": "market_town", "size": 1.1, "skin": Color(0.42, 0.27, 0.17),
		"layers": [["trousers", Color(0.4, 0.33, 0.22)], ["shirt", Color(0.7, 0.25, 0.2)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.84, 0.72, 0.45)]],
		"routine": [
			[6, 0, "", "ZebuMarket", "STAND", true, MARKET],
			[9, 0, "", "Taxi", "STAND", false, NOT_MARKET],
			[13, 0, "", "House_Ratsimba", "INSIDE", true, NOT_MARKET],
			[14, 0, "", "Cockfight_West", "STAND", true, SUNDAY],
			[15, 30, "", "MarketSquare", "WANDER", false, ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "SATURDAY"]],
			[17, 0, "", "House_Ratsimba", "INSIDE", true],
		],
		"greetings": [
			"Un zébu, c'est une banque qui broute !",
			"Le zoma, je vends mes zébus au parc, au nord de la rivière.",
			"Un zébu bien abreuvé prend du poids chaque jour.",
			"Achète-le jeune, revends-le adulte : il aura doublé de prix.",
		],
	},
	# The village school's head teacher: Fara's school fees are paid to her
	# (SchoolManager). Lives in the school's lodging.
	"hanta": {
		"name": "Ramatoa Hanta", "role": "La directrice de l'école du village, l'institutrice de Fara",
		"home": "School", "size": 1.0, "skin": Color(0.52, 0.34, 0.23),
		"layers": [["skirt", Color(0.2, 0.3, 0.55)], ["shirt", Color(0.95, 0.95, 0.98)], ["hair_bun", Color(0.1, 0.08, 0.06)]],
		"routine": [
			[7, 0, "", "School", "STAND", true, SCHOOL_DAYS],
			[8, 30, "", "Square", "WANDER", false, WEEKEND],
			[12, 0, "", "Eatery", "STAND", true],
			[13, 30, "", "School", "STAND", true],
			[17, 30, "", "School", "INSIDE", true],
		],
		"greetings": [
			"Fara est une élève appliquée, tu sais.",
			"L'école, c'est l'avenir du village.",
			"Cette semaine, nous apprenons les fleuves de Madagasikara.",
			"Le lundi matin, les enfants chantent l'hymne devant le drapeau.",
		],
	},
}

func _initialize() -> void:
	_build_villager_scene()
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	for id: String in VILLAGERS:
		var path: String = DATA_DIR + id + ".tres"
		if not ResourceLoader.exists(path):
			ResourceSaver.save(_make_data(VILLAGERS[id]), path)
			print("%s written" % path)
		else:
			# Missing what the table has (written before orders existed...):
			# filled in from the table, only then.
			var data: VillagerData = load(path)
			var changed := false
			if data.orders.is_empty() and not VILLAGERS[id].get("orders", []).is_empty():
				data.orders = _make_orders(VILLAGERS[id])
				changed = true
			if data.role.is_empty() and not VILLAGERS[id].get("role", "").is_empty():
				data.role = VILLAGERS[id]["role"]
				changed = true
			if data.greetings.is_empty():
				data.greetings = PackedStringArray(VILLAGERS[id]["greetings"])
				changed = true
			if data.friendship_rewards.is_empty() and not VILLAGERS[id].get("gifts", []).is_empty():
				data.friendship_rewards = _make_gifts(VILLAGERS[id])
				changed = true
			if "--routines" in OS.get_cmdline_user_args():
				data.routine = _make_routine(VILLAGERS[id])
				changed = true
			if changed:
				ResourceSaver.save(data, path)
				print("%s: completed from the table" % path)
	for zone_id: String in ZONES:
		_place_in_zone(zone_id)
	quit()

func _build_villager_scene() -> void:
	var villager := CharacterBody2D.new()
	villager.name = "Villager"
	villager.set_script(load("res://entities/villager/villager.gd"))
	villager.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Animals layer: the player (who masks it) bumps into them; they mask
	# nothing - they keep to the roads and wait for the player themselves.
	villager.collision_layer = 8
	villager.collision_mask = 0

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	_add(villager, villager, shape)

	var visual := Node2D.new()
	visual.name = "VillagerVisual"
	visual.set_script(load("res://entities/villager/villager_visual.gd"))
	_add(villager, villager, visual)

	var bubble := Label.new()
	bubble.name = "Bubble"
	bubble.visible = false
	bubble.position = Vector2(-90, -136)
	bubble.size = Vector2(180, 22)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.z_index = 40
	bubble.z_as_relative = false
	var settings := LabelSettings.new()
	settings.font_size = 13
	settings.outline_size = 5
	settings.outline_color = Color(0.1, 0.07, 0.05)
	bubble.label_settings = settings
	_add(villager, villager, bubble)

	# Talking to them: the player's interaction detector finds this.
	var talk: Area2D = (load(INTERACTABLE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	talk.name = "InteractableComponent"
	_add(villager, villager, talk) # its reach is set by Villager (TALK_REACH)

	# "!" / "?" over the head (orders).
	var mark := Label.new()
	mark.name = "Mark"
	mark.visible = false
	mark.position = Vector2(-12, -160)
	mark.size = Vector2(24, 30)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.z_index = 41
	mark.z_as_relative = false
	var mark_settings := LabelSettings.new()
	mark_settings.font_size = 24
	mark_settings.font_color = Color(1.0, 0.82, 0.25)
	mark_settings.outline_size = 6
	mark_settings.outline_color = Color(0.25, 0.14, 0.05)
	mark.label_settings = mark_settings
	_add(villager, villager, mark)

	_save(villager, VILLAGER_SCENE)
	villager.free()

func _make_routine(spec: Dictionary) -> Array[VillagerStop]:
	var routine: Array[VillagerStop] = []
	for entry: Array in spec["routine"]:
		var stop := VillagerStop.new()
		stop.hour = entry[0]
		stop.minute = entry[1]
		stop.zone = entry[2]
		stop.spot = entry[3]
		stop.activity = VillagerStop.Activity[entry[4]]
		stop.rain_proof = entry[5]
		if entry.size() > 6:
			var weekdays: Array = []
			for day_name: String in entry[6]:
				weekdays.append(GameClock.Weekday[day_name])
			stop.days = VillagerStop.days_mask(weekdays)
		if entry.size() > 7:
			stop.only_if = entry[7].get("only_if", "")
			stop.unless = entry[7].get("unless", "")
		routine.append(stop)
	return routine

func _make_data(spec: Dictionary) -> VillagerData:
	var look := VillagerLook.new()
	look.skin_color = spec["skin"]
	var layers: Array[VillagerLayer] = []
	for entry: Array in spec["layers"]:
		var layer := VillagerLayer.new()
		layer.texture = load(LAYERS % entry[0])
		layer.color = entry[1]
		layers.append(layer)
	look.layers = layers
	var data := VillagerData.new()
	data.display_name = spec["name"]
	data.role = spec.get("role", "")
	data.home_zone = spec.get("home_zone", "village")
	data.family = spec.get("family", false)
	data.home = spec["home"]
	data.size = spec["size"]
	data.look = look
	data.routine = _make_routine(spec)
	data.greetings = PackedStringArray(spec["greetings"])
	data.orders = _make_orders(spec)
	data.friendship_rewards = _make_gifts(spec)
	return data

func _make_orders(spec: Dictionary) -> Array[OrderTemplate]:
	var orders: Array[OrderTemplate] = []
	for entry: Array in spec.get("orders", []):
		var order := OrderTemplate.new()
		order.item_id = entry[0]
		order.quantity = Vector2i(entry[1], entry[2])
		order.unit_reward = entry[3]
		order.days = entry[4]
		order.request_line = entry[5]
		order.thanks_line = entry[6]
		orders.append(order)
	return orders

func _make_gifts(spec: Dictionary) -> Array[FriendshipReward]:
	var gifts: Array[FriendshipReward] = []
	for entry: Array in spec.get("gifts", []):
		var gift := FriendshipReward.new()
		gift.hearts = entry[0]
		gift.item_id = entry[1]
		gift.quantity = entry[2]
		gift.line = entry[3]
		gifts.append(gift)
	return gifts

func _place_in_zone(zone_id: String) -> void:
	var table: Dictionary = ZONES[zone_id]
	var path: String = table["scene"]
	var zone: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for old in ["VillagerRoads", "Villagers", "NeighbourPaddies"]:
		if zone.has_node(old):
			var node := zone.get_node(old)
			zone.remove_child(node)
			node.free()

	var roads := Node2D.new()
	roads.name = "VillagerRoads"
	roads.set_script(load("res://entities/villager/villager_roads.gd"))
	roads.set("zone_id", zone_id)
	_add(zone, zone, roads)
	for road_name: String in table["roads"]:
		var line := Line2D.new()
		line.name = road_name
		line.points = PackedVector2Array(table["roads"][road_name])
		line.width = 6.0
		line.default_color = Color(1.0, 0.85, 0.3, 0.6)
		_add(zone, roads, line)
	var spots := Node2D.new()
	spots.name = "Spots"
	_add(zone, roads, spots)
	for spot_name: String in table["spots"]:
		var marker := Marker2D.new()
		marker.name = spot_name
		marker.position = table["spots"][spot_name]
		marker.gizmo_extents = 16.0
		_add(zone, spots, marker)

	for tree_name: String in table["remove_trees"]:
		var tree := zone.get_node_or_null("Trees/" + tree_name)
		if tree != null:
			tree.get_parent().remove_child(tree)
			tree.free()
			print("%s: tree %s removed" % [path, tree_name])

	if not table["paddies"].is_empty():
		var paddies := Node2D.new()
		paddies.name = "NeighbourPaddies"
		paddies.y_sort_enabled = true
		_add(zone, zone, paddies)
		var ground: Node2D = zone.get_node("GroundLayer")
		for i in table["paddies"].size():
			var entry: Array = table["paddies"][i]
			var paddy := Node2D.new()
			paddy.name = "Paddy%d" % (i + 1)
			paddy.set_script(load("res://structures/farm/village_paddy/village_paddy.gd"))
			paddy.y_sort_enabled = true
			# On the ground grid, like everything else on the map.
			paddy.position = ground.position + Vector2(entry[0] * TILE)
			paddy.set("size", entry[1])
			_add(zone, paddies, paddy)
			# No tall grass growing in the water.
			var grass: TileMapLayer = zone.get_node_or_null("TallGrassLayer")
			if grass != null:
				for x in entry[1].x:
					for y in entry[1].y:
						var at: Vector2 = paddy.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
						grass.erase_cell(grass.local_to_map(grass.to_local(at)))

	var villagers := Node2D.new()
	villagers.name = "Villagers"
	villagers.y_sort_enabled = true
	_add(zone, zone, villagers)
	var scene: PackedScene = load(VILLAGER_SCENE)
	for id: String in VILLAGERS:
		var spec: Dictionary = VILLAGERS[id]
		if not _passes_through(spec, zone_id):
			continue
		var villager: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		# By id, not display name: "mother" -> Mother, "neny_soa" -> NenySoa.
		villager.name = id.to_pascal_case()
		villager.set("data", load(DATA_DIR + id + ".tres"))
		# Placed by the clock in game; here, somewhere sensible to find it.
		villager.position = table["spots"].get(spec["home"], table["spots"].values()[0])
		_add(zone, villagers, villager)

	_save(zone, path)
	zone.free()

## Whether a villager's day passes through `zone_id`: their home zone, or
## a step there.
func _passes_through(spec: Dictionary, zone_id: String) -> bool:
	if spec.get("home_zone", "village") == zone_id:
		return true
	for entry: Array in spec["routine"]:
		if entry[2] == zone_id:
			return true
	return false

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
