import GameController
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
    private var lastUpdateTime: TimeInterval = 0
    private var wasDifficultyPending = false
    private let arenaSize = CGSize(width: 1200, height: 700)
    private var wallBoundaryY: CGFloat = 0

    func configure(session: GameSession) {
        self.session = session
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1)
        physicsWorld.gravity = .zero
        isUserInteractionEnabled = true

        removeAllChildren()
        doorZones.removeAll()
        lastUpdateTime = 0

        addChild(worldNode)
        buildCorridor()
        spawnCharacters()

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = player.position

        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.fontSize = 12
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position = CGPoint(x: 0, y: size.height / 2 - 100)
        hint.zPosition = 100
        hintLabel = hint
        cameraNode.addChild(hint)
        updateHint(for: nil)
    }

    private func buildCorridor() {
        // ── Floor ──────────────────────────────────────────────────────────────
        let floor = SKSpriteNode(
            color: UIColor(red: 0.11, green: 0.15, blue: 0.19, alpha: 1),
            size: arenaSize
        )
        floor.zPosition = -10
        worldNode.addChild(floor)

        let tileSize: CGFloat = 56
        let cols = Int(arenaSize.width / tileSize) + 1
        let rows = Int(arenaSize.height / tileSize) + 1
        for r in 0..<rows {
            for c in 0..<cols {
                if (r + c) % 2 == 0 { continue }
                let tile = SKSpriteNode(
                    color: UIColor.white.withAlphaComponent(0.055),
                    size: CGSize(width: tileSize - 1.5, height: tileSize - 1.5)
                )
                tile.position = CGPoint(
                    x: -arenaSize.width / 2 + tileSize / 2 + CGFloat(c) * tileSize,
                    y: -arenaSize.height / 2 + tileSize / 2 + CGFloat(r) * tileSize
                )
                tile.zPosition = -9
                worldNode.addChild(tile)
            }
        }

        // Central polished aisle strip
        let aisle = SKSpriteNode(
            color: UIColor.white.withAlphaComponent(0.028),
            size: CGSize(width: arenaSize.width, height: 130)
        )
        aisle.position = CGPoint(x: 0, y: -35)
        aisle.zPosition = -8
        worldNode.addChild(aisle)

        // ── Back wall ──────────────────────────────────────────────────────────
        let wallH: CGFloat = 185
        let wallY = arenaSize.height / 2 - wallH / 2
        // Stop player at the facade base so they can't walk into the storefronts.
        // storeRowY(120) - facadeHalfH(85) - playerHalfH(18) ≈ 17; add 10px clearance.
        wallBoundaryY = 27
        let wall = SKSpriteNode(
            color: UIColor(red: 0.09, green: 0.13, blue: 0.17, alpha: 1),
            size: CGSize(width: arenaSize.width, height: wallH)
        )
        wall.position = CGPoint(x: 0, y: wallY)
        wall.zPosition = -6
        worldNode.addChild(wall)

        // Cove molding at top of back wall
        let cove = SKSpriteNode(
            color: UIColor.white.withAlphaComponent(0.09),
            size: CGSize(width: arenaSize.width, height: 4)
        )
        cove.position = CGPoint(x: 0, y: wallY + wallH / 2 - 2)
        cove.zPosition = -5
        worldNode.addChild(cove)

        // Wainscoting panel at base of back wall
        let wainH: CGFloat = 42
        let wainY = wallY - wallH / 2 + wainH / 2
        let wainPanel = SKSpriteNode(
            color: UIColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1),
            size: CGSize(width: arenaSize.width, height: wainH)
        )
        wainPanel.position = CGPoint(x: 0, y: wainY)
        wainPanel.zPosition = -5
        worldNode.addChild(wainPanel)

        let wainRail = SKSpriteNode(
            color: UIColor.white.withAlphaComponent(0.13),
            size: CGSize(width: arenaSize.width, height: 2.5)
        )
        wainRail.position = CGPoint(x: 0, y: wainY + wainH / 2 + 1)
        wainRail.zPosition = -4
        worldNode.addChild(wainRail)

        // Ceiling lamp fixtures along the back wall top
        let lampY = wallY + wallH / 2 - 10
        for ix in stride(from: -500, through: 500, by: 185) {
            let lamp = SKSpriteNode(
                color: UIColor.white.withAlphaComponent(0.22),
                size: CGSize(width: 36, height: 5)
            )
            lamp.position = CGPoint(x: CGFloat(ix), y: lampY)
            lamp.zPosition = -2
            worldNode.addChild(lamp)

            let lampGlow = SKShapeNode(circleOfRadius: 12)
            lampGlow.fillColor = UIColor.white.withAlphaComponent(0.05)
            lampGlow.strokeColor = .clear
            lampGlow.position = CGPoint(x: CGFloat(ix), y: lampY)
            lampGlow.zPosition = -3
            worldNode.addChild(lampGlow)
        }

        // ── Stores ─────────────────────────────────────────────────────────────
        let stores = StoreLevel.hubStores(mallCleared: session?.mallCleared ?? false)
        let spacing: CGFloat = stores.count > 3 ? 280 : 320
        let startX = -spacing * CGFloat(stores.count - 1) / 2

        for (index, store) in stores.enumerated() {
            let locked: Bool
            if store.isEndless {
                locked = !(session?.mallCleared ?? false)
            } else {
                locked = index > (session?.unlockedStoreIndex ?? 0)
            }
            let x = startX + CGFloat(index) * spacing
            buildLightFixture(at: CGPoint(x: x, y: wallY + 38), store: store, locked: locked)
            buildStorefront(store: store, index: index, at: CGPoint(x: x, y: 120), locked: locked)
        }

        // Pilasters between store bays on back wall
        for i in 0...(stores.count) {
            let px = startX - spacing / 2 + CGFloat(i) * spacing
            let pilaster = SKSpriteNode(
                color: UIColor.white.withAlphaComponent(0.045),
                size: CGSize(width: 14, height: wallH)
            )
            pilaster.position = CGPoint(x: px, y: wallY)
            pilaster.zPosition = -5
            worldNode.addChild(pilaster)
        }

        // Soft boundary
        let edge = SKShapeNode(rectOf: arenaSize)
        edge.strokeColor = UIColor.white.withAlphaComponent(0.07)
        edge.lineWidth = 3
        edge.fillColor = .clear
        edge.zPosition = -4
        worldNode.addChild(edge)
    }

    private func buildLightFixture(at center: CGPoint, store: StoreLevel, locked: Bool) {
        let accentUI = UIColor(store.accentColor)

        let housing = SKSpriteNode(
            color: UIColor.white.withAlphaComponent(locked ? 0.10 : 0.22),
            size: CGSize(width: 22, height: 5)
        )
        housing.position = center
        housing.zPosition = -2
        worldNode.addChild(housing)

        let bulb = SKShapeNode(circleOfRadius: 5)
        bulb.fillColor = accentUI.withAlphaComponent(locked ? 0.28 : 0.72)
        bulb.strokeColor = .clear
        bulb.position = center
        bulb.zPosition = -2
        worldNode.addChild(bulb)

        let coneH: CGFloat = 115
        let coneW: CGFloat = 85
        let conePath = CGMutablePath()
        conePath.move(to: .zero)
        conePath.addLine(to: CGPoint(x: -coneW / 2, y: -coneH))
        conePath.addLine(to: CGPoint(x: coneW / 2, y: -coneH))
        conePath.closeSubpath()
        let cone = SKShapeNode(path: conePath)
        cone.fillColor = accentUI.withAlphaComponent(locked ? 0.016 : 0.048)
        cone.strokeColor = .clear
        cone.position = center
        cone.zPosition = -4
        worldNode.addChild(cone)
    }

    private func buildStorefront(store: StoreLevel, index: Int, at position: CGPoint, locked: Bool) {
        let facadeW: CGFloat = 230
        let facadeH: CGFloat = 170
        let accentUI = UIColor(store.accentColor)
        let alpha: CGFloat = locked ? 0.50 : 1.0

        // ── Ambient glow behind facade (unlocked only) ────────────────────────
        if !locked {
            let glow = SKShapeNode(circleOfRadius: 128)
            glow.fillColor = accentUI.withAlphaComponent(0.055)
            glow.strokeColor = .clear
            glow.position = position
            glow.zPosition = -4
            worldNode.addChild(glow)
        }

        // ── Main facade slab ──────────────────────────────────────────────────
        let facade = SKSpriteNode(
            color: UIColor(store.floorColor),
            size: CGSize(width: facadeW, height: facadeH)
        )
        facade.position = position
        facade.zPosition = -3
        facade.alpha = alpha
        worldNode.addChild(facade)

        // Upper highlight band (depth cue)
        let highlight = SKSpriteNode(
            color: UIColor.white.withAlphaComponent(0.065),
            size: CGSize(width: facadeW, height: 34)
        )
        highlight.position = CGPoint(x: position.x, y: position.y + facadeH / 2 - 17)
        highlight.zPosition = -2.9
        highlight.alpha = alpha
        worldNode.addChild(highlight)

        // Facade outline
        let trim = SKShapeNode(rectOf: CGSize(width: facadeW + 2, height: facadeH + 2), cornerRadius: 4)
        trim.strokeColor = accentUI.withAlphaComponent(locked ? 0.22 : 0.50)
        trim.lineWidth = 1.5
        trim.fillColor = .clear
        trim.position = position
        trim.zPosition = -2
        worldNode.addChild(trim)

        // ── Side columns ──────────────────────────────────────────────────────
        let colW: CGFloat = 13
        let columnDXs: [CGFloat] = [-(facadeW / 2 - colW / 2), facadeW / 2 - colW / 2]
        for dx in columnDXs {
            let col = SKSpriteNode(
                color: UIColor.black.withAlphaComponent(0.22),
                size: CGSize(width: colW, height: facadeH)
            )
            col.position = CGPoint(x: position.x + dx, y: position.y)
            col.zPosition = -2.5
            col.alpha = alpha
            worldNode.addChild(col)

            let edgeDX: CGFloat = dx < 0 ? (colW / 2 - 1) : -(colW / 2 - 1)
            let colEdge = SKSpriteNode(
                color: UIColor.white.withAlphaComponent(0.10),
                size: CGSize(width: 1.5, height: facadeH)
            )
            colEdge.position = CGPoint(x: position.x + dx + edgeDX, y: position.y)
            colEdge.zPosition = -2.4
            colEdge.alpha = alpha
            worldNode.addChild(colEdge)
        }

        // ── Awning (flared trapezoid above facade) ────────────────────────────
        let awningH: CGFloat = 24
        let awningBotW: CGFloat = facadeW + 8
        let awningTopW: CGFloat = facadeW + 28
        let awningPath = CGMutablePath()
        awningPath.move(to: CGPoint(x: -awningBotW / 2, y: 0))
        awningPath.addLine(to: CGPoint(x: awningBotW / 2, y: 0))
        awningPath.addLine(to: CGPoint(x: awningTopW / 2, y: awningH))
        awningPath.addLine(to: CGPoint(x: -awningTopW / 2, y: awningH))
        awningPath.closeSubpath()
        let awning = SKShapeNode(path: awningPath)
        awning.fillColor = accentUI.withAlphaComponent(locked ? 0.28 : 0.68)
        awning.strokeColor = accentUI.withAlphaComponent(locked ? 0.18 : 0.85)
        awning.lineWidth = 1.5
        awning.position = CGPoint(x: position.x, y: position.y + facadeH / 2)
        awning.zPosition = -1
        worldNode.addChild(awning)

        // Drop shadow under awning base
        let awningEdge = SKSpriteNode(
            color: UIColor.black.withAlphaComponent(0.28),
            size: CGSize(width: awningBotW + 4, height: 5)
        )
        awningEdge.position = CGPoint(x: position.x, y: position.y + facadeH / 2 + 2)
        awningEdge.zPosition = 0
        worldNode.addChild(awningEdge)

        // ── Sign board ────────────────────────────────────────────────────────
        let signH: CGFloat = 26
        let signY = position.y + facadeH / 2 - signH / 2 - 5
        let signBoard = SKShapeNode(
            rectOf: CGSize(width: facadeW - 20, height: signH),
            cornerRadius: 4
        )
        signBoard.fillColor = UIColor.black.withAlphaComponent(0.50)
        signBoard.strokeColor = accentUI.withAlphaComponent(locked ? 0.30 : 0.75)
        signBoard.lineWidth = 1.5
        signBoard.position = CGPoint(x: position.x, y: signY)
        signBoard.zPosition = 2
        worldNode.addChild(signBoard)

        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = store.name.uppercased()
        nameLabel.fontSize = store.isEndless ? 9 : 10
        nameLabel.fontColor = accentUI.withAlphaComponent(locked ? 0.55 : 1.0)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: position.x, y: signY)
        nameLabel.zPosition = 3
        worldNode.addChild(nameLabel)

        // Subtitle line
        let subtitle = SKLabelNode(fontNamed: "Menlo-Bold")
        subtitle.text = store.subtitle
        subtitle.fontSize = 8
        subtitle.fontColor = SKColor(white: 1, alpha: locked ? 0.30 : 0.58)
        subtitle.position = CGPoint(x: position.x, y: signY - signH / 2 - 10)
        subtitle.zPosition = 2
        worldNode.addChild(subtitle)

        // Status / best-score line
        let detail = SKLabelNode(fontNamed: "Menlo-Bold")
        if locked {
            detail.text = store.isEndless ? "CLEAR MALL" : "LOCKED"
        } else if let best = session?.formattedBest(for: store) {
            detail.text = best
        } else {
            detail.text = store.isEndless ? "ENDLESS" : "ENTER"
        }
        detail.fontSize = 10
        detail.fontColor = locked
            ? SKColor(white: 1, alpha: 0.40)
            : SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        detail.position = CGPoint(x: position.x, y: signY - signH / 2 - 25)
        detail.zPosition = 2
        worldNode.addChild(detail)

        // ── Display windows flanking door ─────────────────────────────────────
        let doorW: CGFloat = 44
        let winW: CGFloat = 50
        let winH: CGFloat = 52
        let winY = position.y - 12
        let winSpacing = doorW / 2 + winW / 2 + 6

        let sides: [CGFloat] = [-1, 1]
        for side in sides {
            let winX = position.x + side * winSpacing
            let winCenter = CGPoint(x: winX, y: winY)

            let win = SKSpriteNode(
                color: UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 0.88),
                size: CGSize(width: winW, height: winH)
            )
            win.position = winCenter
            win.zPosition = -1
            win.alpha = alpha
            worldNode.addChild(win)

            let winFrame = SKShapeNode(
                rectOf: CGSize(width: winW + 2, height: winH + 2),
                cornerRadius: 2
            )
            winFrame.strokeColor = accentUI.withAlphaComponent(locked ? 0.22 : 0.50)
            winFrame.lineWidth = 1.5
            winFrame.fillColor = .clear
            winFrame.position = winCenter
            winFrame.zPosition = 0
            worldNode.addChild(winFrame)

            // Shelf rails
            let shelfAlphas: [CGFloat] = [0.25, 0.22, 0.20]
            for i in 0..<3 {
                let shelfY = winY - winH / 2 + 10 + CGFloat(i) * 15
                let shelf = SKSpriteNode(
                    color: accentUI.withAlphaComponent(locked ? 0.12 : shelfAlphas[i]),
                    size: CGSize(width: winW - 10, height: 1.5)
                )
                shelf.position = CGPoint(x: winX, y: shelfY)
                shelf.zPosition = 1
                worldNode.addChild(shelf)

                // Merchandise silhouettes on each shelf
                if !locked {
                    let itemHeights: [CGFloat] = [7, 9, 7]
                    for j in 0..<3 {
                        let itemX = winX - 14 + CGFloat(j) * 14
                        let itemH = itemHeights[j]
                        let item = SKSpriteNode(
                            color: accentUI.withAlphaComponent(0.30 + CGFloat(j) * 0.06),
                            size: CGSize(width: 6, height: itemH)
                        )
                        item.position = CGPoint(x: itemX, y: shelfY + itemH / 2 + 1)
                        item.zPosition = 1
                        worldNode.addChild(item)
                    }
                }
            }
        }

        // ── Door ──────────────────────────────────────────────────────────────
        let doorSize = CGSize(width: doorW, height: 64)
        let doorPos = CGPoint(
            x: position.x,
            y: position.y - facadeH / 2 + doorSize.height / 2
        )
        let door = SKSpriteNode(
            color: locked
                ? UIColor.black.withAlphaComponent(0.62)
                : UIColor(red: 0.04, green: 0.07, blue: 0.10, alpha: 0.90),
            size: doorSize
        )
        door.position = doorPos
        door.zPosition = -1
        door.name = "door_\(store.id)"
        worldNode.addChild(door)

        let doorFrame = SKShapeNode(
            rectOf: CGSize(width: doorSize.width + 8, height: doorSize.height + 4),
            cornerRadius: 3
        )
        doorFrame.strokeColor = accentUI.withAlphaComponent(locked ? 0.35 : 0.85)
        doorFrame.lineWidth = 2.5
        doorFrame.fillColor = .clear
        doorFrame.position = doorPos
        doorFrame.zPosition = 0
        worldNode.addChild(doorFrame)

        if !locked {
            // Door handle knob
            let handle = SKShapeNode(circleOfRadius: 3.5)
            handle.fillColor = accentUI.withAlphaComponent(0.65)
            handle.strokeColor = .clear
            handle.position = CGPoint(x: doorPos.x + 15, y: doorPos.y)
            handle.zPosition = 1
            worldNode.addChild(handle)
        } else {
            // Padlock body
            let lockBodyPath = CGPath(
                roundedRect: CGRect(x: -10, y: -8, width: 20, height: 16),
                cornerWidth: 3, cornerHeight: 3, transform: nil
            )
            let lockBody = SKShapeNode(path: lockBodyPath)
            lockBody.fillColor = SKColor(white: 0.82, alpha: 0.88)
            lockBody.strokeColor = SKColor(white: 0.50, alpha: 0.60)
            lockBody.lineWidth = 1
            lockBody.position = doorPos
            lockBody.zPosition = 3
            worldNode.addChild(lockBody)

            // Padlock shackle (U-arc above body)
            let shacklePath = CGMutablePath()
            shacklePath.addArc(
                center: CGPoint(x: 0, y: 10),
                radius: 7.5,
                startAngle: 0,
                endAngle: .pi,
                clockwise: false
            )
            let shackle = SKShapeNode(path: shacklePath)
            shackle.strokeColor = SKColor(white: 0.82, alpha: 0.88)
            shackle.lineWidth = 3.5
            shackle.lineCap = .round
            shackle.fillColor = .clear
            shackle.position = doorPos
            shackle.zPosition = 3
            worldNode.addChild(shackle)
        }

        // ── Door entry zone ───────────────────────────────────────────────────
        let zone = CGRect(
            x: doorPos.x - 40,
            y: doorPos.y - 50,
            width: 80,
            height: 90
        )
        doorZones.append((store: store, index: index, rect: zone, locked: locked))

        // ── Invisible tap target ──────────────────────────────────────────────
        let tap = SKSpriteNode(color: .clear, size: CGSize(width: facadeW, height: facadeH))
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

        let difficultyPending = session.pendingStoreForDifficulty != nil
        if wasDifficultyPending, !difficultyPending {
            // Picker just closed — stop re-triggering while still standing in the door.
            enterCooldown = 1.5
            nudgeOutOfDoorIfNeeded()
            session.moveVector = .zero
        }
        wasDifficultyPending = difficultyPending

        if difficultyPending {
            session.moveVector = .zero
            let rawDt: TimeInterval
            if lastUpdateTime == 0 {
                rawDt = 1.0 / 60.0
            } else {
                rawDt = currentTime - lastUpdateTime
            }
            lastUpdateTime = currentTime
            let dt = min(max(rawDt, 0), 1.0 / 20.0)
            updatePlayer(dt: dt, session: session)
            updateCompanion(dt: dt)
            updateCamera()
            return
        }

        if GameControllerManager.shared.isConnected {
            GameControllerManager.shared.pollMovement(into: session)
        }
        if GCKeyboard.coalesced != nil {
            GameControllerManager.shared.pollKeyboard(into: session)
        }
        let rawDt: TimeInterval
        if lastUpdateTime == 0 {
            rawDt = 1.0 / 60.0
        } else {
            rawDt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        let dt = min(max(rawDt, 0), 1.0 / 20.0)
        enterCooldown = max(0, enterCooldown - dt)

        updatePlayer(dt: dt, session: session)
        updateCompanion(dt: dt)
        updateCamera()
        checkDoorEntry(session: session)
    }

    private func nudgeOutOfDoorIfNeeded() {
        for zone in doorZones where !zone.locked && zone.rect.contains(player.position) {
            player.position.y = min(player.position.y, zone.rect.minY - 16)
            break
        }
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
                hintLabel.text = zone.store.isEndless
                    ? "Clear Grocery to unlock Midnight Mall"
                    : "Locked — clear the previous store first"
            } else {
                hintLabel.text = zone.store.isEndless
                    ? "Entering \(zone.store.name)…"
                    : "Choose difficulty · \(zone.store.name)"
            }
        } else {
            hintLabel.text = "Walk into a store door  ·  Tap a storefront to enter"
        }
    }

    private func enterStore(_ store: StoreLevel) {
        guard enterCooldown <= 0 else { return }
        enterCooldown = 1
        AudioManager.shared.playSFX(.door)
        if store.isEndless {
            session?.startStore(store)
        } else {
            session?.moveVector = .zero
            session?.pendingStoreForDifficulty = store
        }
    }

    private func clampToArena(_ node: SKNode) {
        let halfW = arenaSize.width / 2 - 24
        let halfH = arenaSize.height / 2 - 24
        node.position.x = min(max(node.position.x, -halfW), halfW)
        node.position.y = min(max(node.position.y, -halfH), wallBoundaryY)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard session?.pendingStoreForDifficulty == nil else { return }
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
