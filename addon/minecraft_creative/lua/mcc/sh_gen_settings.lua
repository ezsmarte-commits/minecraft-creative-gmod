-- GENERATED from sheets/settings.json by tools/build.py. Edit the sheet, not this file.
MCC = MCC or {}

MCC.Cfg = {
	block_size = 40, -- source units: One block. 40 units makes a Garry's Mod player 1.8 blocks tall, like Minecraft
	chunk_size = 16, -- blocks: Blocks per chunk edge
	reach_blocks = 6, -- blocks: How far you can break and place
	max_blocks = 60000, -- blocks: Most blocks in one world
	break_delay = 0.15, -- seconds: Time between breaks while holding the button
	place_delay = 0.2, -- seconds: Time between places while holding the button
	max_physics_blocks = 256, -- blocks: Most blocks one physics switch converts
	max_loose_props = 400, -- props: Most block props at once; the oldest are removed past this
	prop_shrink = 0.5, -- source units: Gap left on each side of a block prop so stacked props don't jam
	jump_power = 250, -- source units/s: Jump speed; about 1.25 blocks high at default gravity
	double_tap_window = 0.3, -- seconds: Two jump presses within this toggle flying
	fly_speed = 330, -- source units/s: Flying speed
	fly_sprint_speed = 660, -- source units/s: Flying speed holding sprint
	fly_accel = 0.25, -- fraction per tick: How quickly flight reaches its target speed
	tnt_fuse = 4, -- seconds: TNT fuse after lighting
	tnt_chain_fuse_min = 0.5, -- seconds: Shortest fuse for TNT set off by another explosion
	tnt_chain_fuse_max = 1.5, -- seconds: Longest fuse for TNT set off by another explosion
	tnt_radius = 4, -- blocks: Blocks inside this radius are blasted loose
	tnt_max_props = 60, -- props: Blasted blocks that fly as props; the rest are destroyed
	tnt_damage = 120, -- damage: Explosion damage at the centre
	tnt_fling_speed = 550, -- source units/s: How hard blasted blocks are thrown
	mesh_rebuilds_per_frame = 4, -- chunks: Chunk meshes rebuilt per frame on the client
	help_seconds = 20, -- seconds: How long the controls help shows after spawning
}
