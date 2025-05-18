<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8" />
<title>La Tour des Épreuves - Prototype avec images corrigées</title>
<script src="https://cdn.jsdelivr.net/npm/phaser@3/dist/phaser.js"></script>
<style>
  body { margin: 0; background: #000; }
  #game-container { margin: auto; display: block; width: 600px; height: 400px; }
</style>
</head>
<body>
<div id="game-container"></div>

<script>
// Configuration Phaser
const config = {
  type: Phaser.AUTO,
  width: 600,
  height: 400,
  parent: 'game-container',
  physics: {
    default: 'arcade',
    arcade: { debug: false }
  },
  scene: {
    preload,
    create,
    update
  }
};

const game = new Phaser.Game(config);

let player;
let cursors;
let potions;
let enemies;
let score = 0;
let scoreText;
let life = 5;
let lifeText;
let invincible = false;
let invincibleTimer = 0;

function preload(){
  // Images testées et fiables hébergées sur Phaser Assets
  this.load.image('background', 'https://labs.phaser.io/assets/skies/underwater2.png');
  this.load.spritesheet('player', 'https://labs.phaser.io/assets/sprites/dude.png', { frameWidth: 32, frameHeight: 48 });
  this.load.image('potion', 'https://labs.phaser.io/assets/sprites/potion-blue.png');
  this.load.spritesheet('enemy', 'https://labs.phaser.io/assets/sprites/baddie.png', { frameWidth: 32, frameHeight: 32 });
}

function create(){
  // Arrière-plan
  this.add.image(300, 200, 'background').setScale(1.2);

  // Joueur
  player = this.physics.add.sprite(300, 350, 'player');
  player.setCollideWorldBounds(true);
  player.setScale(1.5);

  // Animations joueur
  this.anims.create({
    key: 'left',
    frames: this.anims.generateFrameNumbers('player', { start: 0, end: 3 }),
    frameRate: 10,
    repeat: -1
  });
  this.anims.create({
    key: 'turn',
    frames: [ { key: 'player', frame: 4 } ],
    frameRate: 20
  });
  this.anims.create({
    key: 'right',
    frames: this.anims.generateFrameNumbers('player', { start: 5, end: 8 }),
    frameRate: 10,
    repeat: -1
  });

  // Potions groupe
  potions = this.physics.add.group();
  spawnPotion(this);

  // Ennemis groupe
  enemies = this.physics.add.group();
  for(let i=0; i<3; i++){
    spawnEnemy(this);
  }

  // Collisions joueur <-> potions
  this.physics.add.overlap(player, potions, collectPotion, null, this);

  // Collisions joueur <-> ennemis
  this.physics.add.collider(player, enemies, hitEnemy, null, this);

  // Clavier
  cursors = this.input.keyboard.createCursorKeys();

  // Texte score & vie
  scoreText = this.add.text(10, 10, 'Score: 0', { fontSize: '20px', fill: '#fff' });
  lifeText = this.add.text(10, 35, 'Vie: 5', { fontSize: '20px', fill: '#fff' });
}

function update(time, delta){
  player.setVelocity(0);

  if(cursors.left.isDown){
    player.setVelocityX(-160);
    player.anims.play('left', true);
  } else if(cursors.right.isDown){
    player.setVelocityX(160);
    player.anims.play('right', true);
  } else {
    player.anims.play('turn');
  }

  if(cursors.up.isDown){
    player.setVelocityY(-160);
  } else if(cursors.down.isDown){
    player.setVelocityY(160);
  }

  // Ennemis bougent horizontalement
  enemies.children.iterate(function(enemy){
    if(enemy.x <= 50){
      enemy.setVelocityX(Phaser.Math.Between(50, 100));
      enemy.flipX = false;
    } else if(enemy.x >= 550){
      enemy.setVelocityX(Phaser.Math.Between(-100, -50));
      enemy.flipX = true;
    }
  });

  // Invincibilité timer
  if(invincible){
    invincibleTimer -= delta;
    if(invincibleTimer <= 0){
      invincible = false;
