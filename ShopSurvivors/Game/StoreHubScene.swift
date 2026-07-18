import SpriteKit
import SwiftUI

@MainActor
final class StoreHubScene: SKScene {
    private weak var session: GameSession?
    private var player: PlayerNode!
    private var companion: CompanionNode!
    private var worldNode = SKNode()
    private var cameraNode = SKCameraNode()
    private var doorZones: [(store: StoreLevel, index: Int, rect: CGRect, locked: Bool)] = []
    private var enterCooldown: TimeInterval = 0
    private var hintLabel: SKLabelNode?
    private let arenaSize = CGSize(width: 1200, height: 700)

    func configure(session: GameSession) {
        self.session = session
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1)
        physicsWorld.gravity = .zero
        isUserInteractionEnabled = true

        removeAllChildren()
        doorZones.removeAll()

        addChild(worldNode)
        buildCorridor()
        spawnCharacters()

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = player.position

        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.fontSize = 12
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position = CGPoint(x: 0, y: size.height / 2 - 28)
        hint.zPosition = 100
        hintLabel = hint
        cameraNode.addChild(hint)
        updateHint(for: nil)
    }

    private func buildCorridor() {
        let floor = SKSpriteNode(color: UIColor(red: 0.14, green: 0.18, blue: 0.22, alpha: 1), size: arenaSize)
        floor.zPosition = -10
        worldNode.addChild(floor)

        let tileSize: CGFloat = 56
        let cols = Int(arenaSize.width / tileSize)
        let rows = Int(arenaSize.height / tileSize)
        for r in 0..<rows {
            for c in 0..<cols {
                if (r + c) % 2 == 0 { continue }
                let tile = SKSpriteNode(
                    color: UIColor.white.withAlphaComponent(0.04),
                    size: CGSize(width: tileSize, height: tileSize)
                )
                tile.position = CGPoint(
                    x: -arenaSize.width / 2 + tileSize / 2 + CGFloat(c) * tileSize,
                    y: -arenaSize.height / 2 + tileSize / 2 + CGFloat(r) * tileSize
                )
                tile.zPosition = -9
                worldNode.addChild(tile)
            }
        }

        // Back wall strip
        let wall = SKSpriteNode(
            color: UIColor(red: 0.1, green: 0.14, blue: 0.18, alpha: 1),
            size: CGSize(width: arenaSize.width, height: 180)
        )
        wall.position = CGPoint(x: 0, y: arenaSize.height / 2 - 90)
        wall.zPosition = -5
        worldNode.addChild(wall)

        let stores = StoreLevel.all
        let spacing: CGFloat = 320
        let startX = -spacing * CGFloat(stores.count - 1) / 2

        for (index, store) in stores.enumerated() {
            let locked = index > (session?.unlockedStoreIndex ?? 0)
            let x = startX + CGFloat(index) * spacing
            buildStorefront(store: store, index: index, at: CGPoint(x: x, y: 120), locked: locked)
        }

        // Soft boundary walls
        let edge = SKShapeNode(rectOf: arenaSize)
        edge.strokeColor = UIColor.white.withAlphaComponent(0.08)
        edge.lineWidth = 3
        edge.fillColor = .clear
        edge.zPosition = -4
        worldNode.addChild(edge)
    }

    private func buildStorefront(store: StoreLevel, index: Int, at position: CGPoint, locked: Bool) {
        let facadeSize = CGSize(width: 220, height: 160)
        let facade = SKSpriteNode(color: UIColor(store.floorColor), size: facadeSize)
        facade.position = position
        facade.zPosition = -3
        facade.alpha = locked ? 0.45 : 1
        worldNode.addChild(facade)

        let trim = SKShapeNode(rectOf: facadeSize, cornerRadius: 6)
        trim.strokeColor = UIColor(store.accentColor).withAlphaComponent(locked ? 0.35 : 0.9)
        trim.lineWidth = 3
        trim.fillColor = .clear
        trim.position = position
        trim.zPosition = -2
        worldNode.addChild(trim)

        // Door opening
        let doorSize = CGSize(width: 56, height: 72)
        let door = SKSpriteNode(
            color: locked
                ? UIColor.black.withAlphaComponent(0.55)
                : UIColor(red: 0.05, green: 0.08, blue: 0.1, alpha: 0.85),
            size: doorSize
        )
        door.position = CGPoint(x: position.x, y: position.y - facadeSize.height / 2 + doorSize.height / 2)
        door.zPosition = -1
        door.name = "door_\(store.id)"
        worldNode.addChild(door)

        let doorFrame = SKShapeNode(rectOf: CGSize(width: doorSize.width + 6, height: doorSize.height + 4), cornerRadius: 2)
        doorFrame.strokeColor = UIColor(store.accentColor)
        doorFrame.lineWidth = 2
        doorFrame.fillColor = .clear
        doorFrame.position = door.position
        doorFrame.zPosition = 0
        worldNode.addChild(doorFrame)

        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = store.name.uppercased()
        nameLabel.fontSize = 11
        nameLabel.fontColor = UIColor(store.accentColor)
        nameLabel.position = CGPoint(x: position.x, y: position.y + 48)
        nameLabel.zPosition = 2
        nameLabel.alpha = locked ? 0.5 : 1
        worldNode.addChild(nameLabel)

        let detail = SKLabelNode(fontNamed: "Menlo-Bold")
        detail.text = locked ? "LOCKED" : "ENTER"
        detail.fontSize = 10
        detail.fontColor = locked
            ? SKColor(white: 1, alpha: 0.45)
            : SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        detail.position = CGPoint(x: position.x, y: position.y + 28)
        detail.zPosition = 2
        worldNode.addChild(detail)

        if locked {
            let lock = SKLabelNode(fontNamed: "Menlo-Bold")
            lock.text = "LOCK"
            lock.fontSize = 12
            lock.fontColor = SKColor(white: 1, alpha: 0.7)
            lock.position = door.position
            lock.zPosition = 3
            worldNode.addChild(lock)
        } else {
            // Shelf prop beside door for store feel
            let shelf = SKSpriteNode(imageNamed: "prop_shelf")
            shelf.texture?.filteringMode = .nearest
            shelf.size = CGSize(width: 48, height: 30)
            shelf.position = CGPoint(x: position.x + 70, y: position.y - 20)
            shelf.zPosition = 1
            shelf.color = UIColor(store.accentColor)
            shelf.colorBlendFactor = 0.3
            worldNode.addChild(shelf)
        }

        let zone = CGRect(
            x: door.position.x - 40,
            y: door.position.y - 50,
            width: 80,
            height: 90
        )
        doorZones.append((store: store, index: index, rect: zone, locked: locked))

        // Invisible tappable nameplate
        let tap = SKSpriteNode(color: .clear, size: facadeSize)
        tap.position = position
        tap.zPosition = 5
        tap.name = "storefront_\(store.id)"
        tap.userData = NSMutableDictionary()
        tap.userData?["storeId"] = store.id
        tap.userData?["locked"] = locked
        worldNode.addChild(tap)
    }

    private func spawnCharacters() {
        player = PlayerNode()
        player.position = CGPoint(x: 0, y: -80)
        worldNode.addChild(player)

        companion = CompanionNode()
        companion.position = CGPoint(x: -50, y: -90)
        companion.setStatus("with you")
        worldNode.addChild(companion)
    }

    override func update(_ currentTime: TimeInterval) {
        guard let session else { return }
        let dt: TimeInterval = 1.0 / 60.0
        enterCooldown = max(0, enterCooldown - dt)

        updatePlayer(dt: dt, session: session)
        updateCompanion(dt: dt)
        updateCamera()
        checkDoorEntry(session: session)
    }

    private func updatePlayer(dt: TimeInterval, session: GameSession) {
        let input = session.moveVector
        let len = hypot(input.dx, input.dy)
        let moving = len > 0.05
        if moving {
            let speed = player.baseSpeed * 1.05
            player.position.x += input.dx / len * speed * CGFloat(dt)
            player.position.y += input.dy / len * speed * CGFloat(dt)
            player.facing = CGVector(dx: input.dx / len, dy: input.dy / len)
        }
        clampToArena(player)
        player.walk.update(sprite: player, moving: moving, facingDX: player.facing.dx, dt: dt)
    }

    private func updateCompanion(dt: TimeInterval) {
        let target = CGPoint(x: player.position.x - 42, y: player.position.y - 10)
        let dx = target.x - companion.position.x
        let dy = target.y - companion.position.y
        let dist = hypot(dx, dy)
        var moving = false
        if dist > 18 {
            let speed: CGFloat = 140
            companion.position.x += dx / dist * speed * CGFloat(dt)
            companion.position.y += dy / dist * speed * CGFloat(dt)
            companion.facingDX = dx
            moving = true
        }
        clampToArena(companion)
        companion.walk.update(sprite: companion, moving: moving, facingDX: companion.facingDX, dt: dt)
    }

    private func updateCamera() {
        let blend: CGFloat = 0.14
        cameraNode.position.x += (player.position.x - cameraNode.position.x) * blend
        cameraNode.position.y += (player.position.y - cameraNode.position.y) * blend
        session?.cameraWorldPosition = cameraNode.position
    }

    private func checkDoorEntry(session: GameSession) {
        for zone in doorZones {
            if zone.rect.contains(player.position) {
                updateHint(for: zone)
                if !zone.locked, enterCooldown <= 0 {
                    enterStore(zone.store)
                }
                return
            }
        }
        updateHint(for: nil)
    }

    private func updateHint(for zone: (store: StoreLevel, index: Int, rect: CGRect, locked: Bool)?) {
        guard let hintLabel else { return }
        if let zone {
            if zone.locked {
                hintLabel.text = "Locked — clear the previous store first"
            } else {
                hintLabel.text = "Entering \(zone.store.name)…"
            }
        } else {
            hintLabel.text = "Walk into a store door  ·  Tap a storefront to enter"
        }
    }

    private func enterStore(_ store: StoreLevel) {
        guard enterCooldown <= 0 else { return }
        enterCooldown = 1
        AudioManager.shared.playSFX(.door)
        session?.startStore(store)
    }

    private func clampToArena(_ node: SKNode) {
        let halfW = arenaSize.width / 2 - 24
        let halfH = arenaSize.height / 2 - 24
        node.position.x = min(max(node.position.x, -halfW), halfW)
        node.position.y = min(max(node.position.y, -halfH), halfH)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: worldNode)
        let hit = worldNode.nodes(at: point)
        for node in hit {
            guard let name = node.name, name.hasPrefix("storefront_"),
                  let storeId = node.userData?["storeId"] as? String,
                  let locked = node.userData?["locked"] as? Bool,
                  let store = StoreLevel.byId(storeId) else { continue }
            if locked {
                updateHint(for: (store: store, index: 0, rect: .zero, locked: true))
                AudioManager.shared.playSFX(.ui, volume: 0.4)
            } else {
                enterStore(store)
            }
            return
        }
    }
}
