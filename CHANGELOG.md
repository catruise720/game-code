# 更新记录

## 2026-09-22：当前调通版

- 玩家：X统一负责普通跳跃、抓链和离链跳跃；Z祈祷；Shift奔跑；方向键移动/攀爬。
- 锁链：攀爬期间只按玩家实体碰撞体与锁链Area2D是否仍重叠判断，不再使用手部高度限制。
- 摄像机：非攀爬状态可用上下键观察，并按世界坐标地图边界限制镜头。
- 房间：新增淡出/淡入转场、命名出生点、出口激活延迟；换场景延迟到物理回调之后，避免删除CollisionObject报错。
- 窗口：V键逻辑移出玩家脚本，由唯一的WindowController处理，修复一次按键切换两次的问题。
- 摄像机观察条件收紧：仅地面NORMAL状态且没有其他操作时，单独按↑或↓才移动镜头。

### 目录职责

- `scripts/player.gd`：角色状态与操作。
- `scripts/climb_chain.gd`、`scripts/prayer_statue.gd`：场景互动。
- `scripts/exploration_camera.gd`：摄像机观察和边界。
- `scripts/rooms/`：房间出口、出生点、房间根节点和全局转场管理。
- `scripts/system/`：与角色玩法无关的全局系统。

### 接入提醒

正式项目需把 `room_manager.gd` 注册为名为 `RoomManager` 的Autoload。`window_controller.gd`可注册为Autoload，或只挂在一个长期存在的节点上；两种方式只能选一种。
