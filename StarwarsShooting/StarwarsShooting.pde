// SpaceShooting Sample / Written by n_ryota
import saito.objloader.*;
OBJModel model;

import processing.video.*;
import ddf.minim.*;  
Movie myMovie;
Minim minim;  
AudioPlayer playerMusic; 

// 変数定義
int PLAYER = 0, ENEMY = 1, EFFECT = 2;      // group定数(enum…)
Player player = new Player(0, 0, 100, 10);  // プレイヤー
ArrayList fighterList = new ArrayList();    // 戦闘機リスト（プレイヤー含む）
ArrayList bulletList = new ArrayList();     // 弾リスト
ArrayList effectList = new ArrayList();     // エフェクトリスト
float cameraShake = 0.0;                    // 現在のカメラの揺れ具合
int clearMillis = 0;                        // クリアタイム
int counttime=0;                            // 
int STAGE = 0;
PImage life1,force1;

//muse
import oscP5.*;
import netP5.*;
final int PORT = 5001;
OscP5 oscP5 = new OscP5(this, PORT);
float[] buffer_acc = new float[3];
float[] buffer_alr = new float[4];
float mX,mY;

// 3D空間に配置する基本オブジェクトクラス
class Chara {
  PMatrix3D matrix = new PMatrix3D();
  PVector pos = new PVector(), vel = new PVector();
  float radius, life;
  int group;
  Chara(float _x, float _y, float _z, float _radius, int _group) {
    pos.x = _x; pos.y = _y; pos.z = _z;
    radius = _radius; life = 100.0; group = _group;
  }
  void roll(float rotX, float rotY, float rotZ) {
    matrix.rotateY(radians(rotY));  matrix.rotateX(radians(rotX));  matrix.rotateZ(radians(rotZ));
  }
  void accel(float speed) {
    vel.x += matrix.m02 * -speed;  vel.y += matrix.m12 * -speed;  vel.z += matrix.m22 * -speed;
  }
  void lookAt(PVector vz) {
    PVector vx = vz.cross(new PVector(0,1,0)); vx.normalize();
    PVector vy = vz.cross(vx); vy.normalize();
    matrix.set(vx.x, vy.x, vz.x, pos.x, vx.y, vy.y, vz.y, pos.y, vx.z, vy.z, vz.z, pos.z, 0, 0, 0, 1);
  }
  void updateMatrix() {
    matrix.m03 = pos.x; matrix.m13 = pos.y; matrix.m23 = pos.z;
  }
  void update() {
    pos.x += vel.x; pos.y += vel.y; pos.z += vel.z;
  }
  boolean isHit(Chara chara) {
    if(group==chara.group) return false;
    else return pos.dist(chara.pos) <= radius + chara.radius;
  }
  boolean damage(float _damage) {
    life-=_damage;
    
    return life<=0.0;
  }
  void draw() {
    pushMatrix(); updateMatrix(); applyMatrix(matrix);
    drawShape();
    popMatrix();
    update();
  }
  void drawShape() {
    fill(255); box(radius);
  }
};

// 戦闘機クラス
class Fighter extends Chara  {
  Fighter(float _x, float _y, float _z, float _radius, int _group) { super(_x, _y, _z, _radius, _group); }
  Bullet shoot(int power, float radian) {
    Bullet bullet = new Bullet(pos.x, pos.y, pos.z, 7, group, power);
    bullet.matrix.set(matrix);
    if(radian>0) bullet.roll(random_pm(radian), random_pm(radian), random_pm(radian));  // 少し向きをランダムにばらけさせる
    bullet.accel(70);
    bulletList.add(bullet);
    return bullet;
  }
}

// プレイヤー戦闘機クラス
class Player extends Fighter {
  Player(float _x, float _y, float _z, float _radius) { super(_x, _y, _z, _radius, PLAYER); }
  void drawShape() {
    stroke(0, 255, 0, 64); strokeWeight(2); noFill();
    translate(0, 0, -10);
    box(radius, radius, radius*5);
    noStroke();
  }
}

// 敵戦闘機クラス
class Enemy extends Fighter {
  int level;
  Enemy(float _x, float _y, float _z, float _radius) {
    super(_x, _y, _z, _radius, ENEMY); 
    level = int(random(3));
  }
  void update() {
    // プレイヤーの方に向いて移動
    PVector vz = new PVector(pos.x-player.pos.x, pos.y-player.pos.y, pos.z-player.pos.z);
    vz.normalize();
    float leapLevel = 0.05 * (1 + level);
    vz.x = lerp(matrix.m02, vz.x, leapLevel); vz.y = lerp(matrix.m12, vz.y, leapLevel); vz.z = lerp(matrix.m22, vz.z, leapLevel); // 現在ベクトルからなめらかに補間
    vz.normalize();
    lookAt(vz);
    accel(0.01 * level);
    super.update();
    if( millis()>3000*(1+level) && 0==(millis() % (100-level*20)) ) shoot(10, radians(10 + 10*level)); // ゲーム開始後、一定秒経過したあと、たまに弾発射
  }
  void drawShape() {
    // モデルの描画
    model.draw();
  }
}

// 弾クラス
class Bullet extends Chara  {
  int power;
  Bullet(float _x, float _y, float _z, float _radius, int _group, int _power) {
    super(_x, _y, _z, _radius, _group);
    power = _power;
  }
  void drawShape() {
    damage(0.5);
    if(group==PLAYER) stroke(0, 128, 255, 128);
    else stroke(255, 0, 0, 128);
    strokeWeight(4); fill(255);
    translate(0, radius*7, 0);
    box(radius, radius, radius*20);
  }
}

// エフェクトクラス
class Effect extends Chara  {
  Effect(float _x, float _y, float _z, float _radius) { super(_x, _y, _z, _radius, EFFECT); }
  void drawShape() {
    damage(2);
    matrix.scale(1.04);
    matrix.rotateX(0.1);
    fill(255, 64, 32, map(life, 0, 100, 0, 128));
    sphereDetail(7); sphere(radius);
  }
}

// 初期化
void setup() {
  size(1050, 600, P3D);
  frameRate(60);
  // OBJファイルの読み込み
  model = new OBJModel(this, "Fighter SF2 N300707.obj");
  model.enableDebug();
  // 座標保存
  model.scale(0.5);
  
  minim = new Minim(this); //initialize
  myMovie = new Movie(this, "StarWarsTelop.mov");
  playerMusic = minim.loadFile("MainTheme.mp3");
  
  fighterList.add(player);
  for(int i=0; i<10; i++) {
    fighterList.add(new Enemy(random(-2000, 2000), random(-2000, 2000), random(-5000, -40000), 150));
  }
  textFont( createFont("Lucida Console", 20) );
}

// 毎フレームの進行と描画
void draw(){
  if (STAGE == 0) {
    myMovie.loop();
    tint(255, 30);
    image(myMovie, 0, 0);
    textAlign(CENTER, BOTTOM);
    text("Click Bottan and Start",525,500);
    counttime++;
    if(counttime>360){
      playerMusic.play();
    }
    if(counttime>3840){
      myMovie.noLoop();
      playerMusic.close(); 
    minim.stop();
      
      STAGE = 1;    
    }
  } else {
   background(0);
  // 宇宙背景、塵
  setLights();
  setPlayerCamera();
  drawStars();

  // プレイヤーと敵
  for (int i=0;i<fighterList.size();i++) {
    Fighter chara = (Fighter) fighterList.get(i);
    chara.draw();
  }

  // エフェクト
  noLights();
  for (int i=0;i<effectList.size();i++) {
    Effect effect = (Effect) effectList.get(i);
    effect.draw();
    if(effect.life<=0) effectList.remove(i--); // 寿命で消滅
  }

  // 弾
  for (int i=0;i<bulletList.size();i++) {
    Bullet bullet = (Bullet) bulletList.get(i);
    bullet.draw();
    for (int j=0;j<fighterList.size();j++) {
      Fighter fighter = (Fighter) fighterList.get(j);
      if(bullet.isHit(fighter)) {  // 弾が当たったらダメージ
        if(fighter==player){
          cameraShake += bullet.power * 0.5;
          if(fighter.damage(bullet.power/(0.7+buffer_alr[0]*9))) {
            fighterList.remove(j--);      // ライフが尽きているので削除
            addExplosionEffect(fighter);  // 爆発エフェクト
            cameraShake += 1.0;           // カメラを少し揺らす
          }
        }else{
           if(fighter.damage(bullet.power*buffer_alr[1]*5)) {
              fighterList.remove(j--);      // ライフが尽きているので削除
              addExplosionEffect(fighter);  // 爆発エフェクト
              cameraShake += 1.0;           // カメラを少し揺らす
            }
        }
       
        
        
        bullet.life = 0;
        break;
      }
    }
    if(bullet.life<=0) bulletList.remove(i--); // 寿命で消滅
  }

  // 情報表示
  camera();
  noLights();
  textMode(SCREEN); textSize(20); textAlign(CENTER, TOP);
  if(player.life>30) fill(0, 255, 0, 128);
  else fill(255, 0, 0, 128);
  if(player.life>0) {
    int enemyNum = fighterList.size()-1;
    if(enemyNum==0) {
      fill(255, 128);
      textSize(40);
      text("MISSION CLEAR", width/2, height/2 - 40);
      if(clearMillis==0) clearMillis = millis();
      text("TIME "+ nf(clearMillis*0.001, 1, 1) + "sec", width/2, height/2 + 30 );
    } else {
      text("" + enemyNum + " enemy" + (enemyNum>1 ? "s " : "" ), width/2, 30);
      textAlign(RIGHT, CENTER);
      text("life " + nf(player.life, 1, 0), width/3, height-30);
      noTint();
      if(player.life>90){
        life1 = loadImage("life1.png");
      }else if(player.life>75){
        life1 = loadImage("life2.png");
      }else if(player.life>60){
        life1 = loadImage("life3.png");
      }else if(player.life>45){
        life1 = loadImage("life4.png");
      }else if(player.life>30){
        life1 = loadImage("life5.png");
      }else{
        life1 = loadImage("life6.png");
      }
      for(int i=0;i<21;i++){
        if(buffer_alr[1] == 0.0) {
          buffer_alr[1] = 0.3;
        }
        if(buffer_alr[1]>i*0.025){
          force1=loadImage("force"+(20-i)+".png");
        }
      }
      image(life1, 10, 30);
      image(force1, 10, 60);
      rectMode(CORNER);
      noStroke();
      rect(20+width/3, height-34, map(player.life, 0, 100, 0, width/3), 5);
    }
  } else {
    textSize(40);
    text("GAME OVER", width/2, height/2);
  }

  //レーダー
  drawRadar();

  input();
  cameraShake *= 0.95;
  
  }
}

// 毎フレームの入力
void input(){
mX=buffer_acc[2]/2+415;  
mY=buffer_acc[0]/2+360;
if(mX>width){mX=width-1;}
if(mX<0){mX=1;}
if(mY>height){mY=height-1;}
if(mY<0){mY=1;}
if(mX>0 && mY>0){ 
float rotYLevel = map(mX, 0, width, -1, 1);  
float rotXLevel = map(mY, 0, height, -1, 1);  
player.roll(rotXLevel * abs(rotXLevel) * 3.0, -rotYLevel * abs(rotYLevel) * 3.0, 0.0f);  
}

  if(player.life>0) {
    if((keyPressed && key==' ') || (mousePressed && mouseButton==RIGHT)) player.accel(0.04);
    else player.vel.mult(0.98);
  }
}


// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}

// マウスボタンを押した瞬間
void mousePressed() {
  if (STAGE == 0) {
    myMovie.noLoop();      // press bottan and finish movie
    playerMusic.close(); 
    minim.stop();
    STAGE = 1;        // new operation 
  } else {
    if(player.life>0 && mouseButton==LEFT) player.shoot(100, 1);
  }
}

// 爆発エフェクトを追加
void addExplosionEffect(Chara chara) {
  for(int i=0; i<3; i++) {
    Effect effect = new Effect(chara.pos.x, chara.pos.y, chara.pos.z, chara.radius);
    effect.vel.set(random_pm(3), random_pm(3), random_pm(3));
    effectList.add(effect);
  }
}

// プレイヤー視点のカメラ
void setPlayerCamera() {
  player.updateMatrix();
  float sl = cameraShake * 0.01;
  PVector sp = new PVector(random_pm(sl), random_pm(sl), random_pm(sl));
  camera(player.pos.x, player.pos.y, player.pos.z,     // 位置
         player.pos.x-player.matrix.m02+sp.x, player.pos.y-player.matrix.m12+sp.y, player.pos.z-player.matrix.m22+sp.z, // 注視点
         player.matrix.m01, player.matrix.m11, player.matrix.m21); // アップベクトル
}

// ライト設定
void setLights() {
  ambientLight(50, 50, 70); 
  directionalLight(255, 255, 255, 0, 1, 0); 
}

// aをbで割った余りを返す
float modulo(float a, float b) {
  return a - floor(a / b) * b;
}

// ±rangeの乱数を返す
float random_pm(float range) {
  return random(-range, range);
}

// 宇宙背景、塵の描画
void drawStars() {
  pushMatrix();
  translate(player.pos.x, player.pos.y, player.pos.z);
  int seed = int(random(1000)); randomSeed(0);
  float range = 500.0;
  PVector starPos = new PVector();
  for(int i=0; i<250; i++) {
    // 遠くの星々
    strokeWeight(int(random(1,3))); stroke(random(128,255));
    starPos.set(random_pm(range*100), random_pm(range*100), random_pm(range*100));
    line(starPos.x, starPos.y, starPos.z, starPos.x, starPos.y, starPos.z);

    // 近くの塵（プレイヤーのまわりに常にあるようにループさせる）
    starPos.set(random(range), random(range), random(range));
    starPos.x = modulo(-player.pos.x + starPos.x, range) - range * 0.5;
    starPos.y = modulo(-player.pos.y + starPos.y, range) - range * 0.5;
    starPos.z = modulo(-player.pos.z + starPos.z, range) - range * 0.5;
    line(starPos.x, starPos.y, starPos.z, starPos.x-player.vel.x*(range*0.001), starPos.y-player.vel.y*(range*0.001), starPos.z-player.vel.z*(range*0.001));
  }
  randomSeed(seed);
  popMatrix();

  // 惑星
  pushMatrix();
  translate(0, 0, 0);
  noStroke();
  fill(0, 0, 255);
  translate(-10000,0,-25000);
  sphereDetail(30);
  sphere(20000);
  popMatrix();
  
}
void oscEvent(OscMessage msg){
  float data1;
  if(msg.checkAddrPattern("/muse/acc")){
    for(int ch = 0; ch < 3; ch++){
      data1 = msg.get(ch).floatValue();
      buffer_acc[ch] = data1;
    }
  }
  float data2;
  if(msg.checkAddrPattern("/muse/elements/alpha_relative")){
    for(int ch = 0; ch < 4; ch++){
      data2 = msg.get(ch).floatValue();
      buffer_alr[ch] = data2;
    }
  }
}

//レーダーの描画
void drawRadar() {
  float radius = 20;
  for (int i=0; i<6; i++) {
    noFill();
    strokeWeight(1.5);
    stroke(255, 0, 0, 128);
    ellipse(width-140,height-120,radius*2,radius*2);
    radius += 15;
  }
  fill(255, 0, 0, 128);
  triangle(width-140,height-125,width-143,height-115,width-137,height-115);
  float x = player.pos.x;
  float y = player.pos.y;
  float z = player.pos.z;
  for (int i=1;i<fighterList.size();i++) {
    Fighter fighter = (Fighter) fighterList.get(i);
    stroke(128, 0, 255, 128);
    fill(128, 0, 255, 128);
    float fx = fighter.pos.x;
    float fy = fighter.pos.y;
    float fz = fighter.pos.z;
    float dx = (fx-x)*player.matrix.m00 + (fy-y)*player.matrix.m10 + (fz-z)*player.matrix.m20;
    float dz = (fx-x)*player.matrix.m02 + (fy-y)*player.matrix.m12 + (fz-z)*player.matrix.m22;
    float a = map(dx, 10000, -10000, width-50, width-230);
    float b = map(dz, 10000, -10000, height-30, height-210);
    ellipse(a, b, 5, 5);
  }
}
