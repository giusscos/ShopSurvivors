import SpriteKit
import SwiftUI

@MainActor
final class GameScene: SKScene, SKPhysicsContactDelegate {
    private weak var session: GameSession?
    private var store: StoreLevel!

    private var player: PlayerNode!
    private var companion: CompanionNode!
    private var worldNode = SKNode()
    private var entityNode = SKNode()

    private var clerks: [ClerkNode] = []
    private var projectiles: [ProjectileNode] = []
    private var coupons: [CouponNode] = []
    private var xpOrbs: [XPOrbNode] = []
    private var interestPoints: [CGPoint] = []
    private var shelfRects: [CGRect] = []

    private var spawnTimer: TimeInterval = 0
    private var weaponCooldowns: [WeaponKind: TimeInterval] = [:]
    private var elapsed: TimeInterval = 0
    private var pitchBannerTimer: TimeInterval = 0
    private var cameraNode = SKCameraNode()
    private var shakeTime: TimeInterval = 0

    private var priceAuraRing: SKShapeNode?
    private var priceAuraRadius: CGFloat = 0
    private var aimGhost: SKNode?
    private var arenaSize = CGSize(width: 1400, height: 900)
    private var shoveSFXCooldown: TimeInterval = 0

    func configure(session: GameSession, store: StoreLevel) {
        self.session = session
        self.store = store
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(store.floorColor)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        isUserInteractionEnabled = true

        addChild(worldNode)
        worldNode.addChild(entityNode)

        buildArena()
        spawnPlayerAndCompanion()

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = player.position
    }

    private func buildArena() {
        interestPoints.removeAll()
        shelfRects.removeAll()

        let floor = SKSpriteNode(color: UIColor(store.floorColor), size: arenaSize)
        floor.zPosition = -10
        worldNode.addChild(floor)

        let tileSize: CGFloat = 64
        let cols = Int(arenaSize.width / tileSize)
        let rows = Int(arenaSize.height / tileSize)
        for r in 0..<rows {
            for c in 0..<cols {
                if (r + c) % 2 == 0 { continue }
                let tile = SKSpriteNode(
                    color: UIColor(store.accentColor).withAlphaComponent(0.08),
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

        for _ in 0..<14 {
            let prop = SKSpriteNode(imageNamed: "prop_shelf")
            prop.texture?.filteringMode = .nearest
            let shelfSize = CGSize(width: 56, height: 36)
            prop.size = shelfSize
            let pos = CGPoint(
                x: CGFloat.random(in: -arenaSize.width / 2 + 100...arenaSize.width / 2 - 100),
                y: CGFloat.random(in: -arenaSize.height / 2 + 100...arenaSize.height / 2 - 100)
            )
            if hypot(pos.x, pos.y) < 160 { continue }
            prop.position = pos
            prop.zPosition = -5
            prop.color = UIColor(store.accentColor)
            prop.colorBlendFactor = 0.25
            worldNode.addChild(prop)

            let inset: CGFloat = 4
            shelfRects.append(CGRect(
                x: pos.x - shelfSize.width / 2 + inset,
                y: pos.y - shelfSize.height / 2 + inset,
                width: shelfSize.width - inset * 2,
                height: shelfSize.height - inset * 2
            ))

            // Browse spots beside shelves (clear of collision boxes)
            let sideSpots = [
                CGPoint(x: pos.x, y: pos.y - 52),
                CGPoint(x: pos.x, y: pos.y + 52),
                CGPoint(x: pos.x - 50, y: pos.y),
                CGPoint(x: pos.x + 50, y: pos.y),
            ]
            for spot in sideSpots.shuffled().prefix(2) {
                let clamped = clampPoint(spot)
                if isWalkable(clamped, radius: 14) {
                    interestPoints.append(clamped)
                }
            }
        }

        for _ in 0..<10 {
            for _ in 0..<8 {
                let candidate = CGPoint(
                    x: CGFloat.random(in: -arenaSize.width / 2 + 100...arenaSize.width / 2 - 100),
                    y: CGFloat.random(in: -arenaSize.height / 2 + 100...arenaSize.height / 2 - 100)
                )
                if isWalkable(candidate, radius: 14) {
                    interestPoints.append(candidate)
                    break
                }
            }
        }

        // Drop any browse spots that later shelves covered.
        interestPoints = interestPoints.filter { isWalkable($0, radius: 14) }
        if interestPoints.isEmpty {
            interestPoints.append(.zero)
        }

        let border = SKShapeNode(rectOf: arenaSize)
        border.strokeColor = UIColor(store.accentColor).withAlphaComponent(0.6)
        border.lineWidth = 4
        border.fillColor = .clear
        border.zPosition = -8
        worldNode.addChild(border)

        let wallBody = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: -arenaSize.width / 2,
            y: -arenaSize.height / 2,
            width: arenaSize.width,
            height: arenaSize.height
        ))
        wallBody.categoryBitMask = PhysicsCategory.wall
        wallBody.friction = 0
        let walls = SKNode()
        walls.physicsBody = wallBody
        worldNode.addChild(walls)
    }

    private func spawnPlayerAndCompanion() {
        player = PlayerNode()
        player.position = CGPoint(x: -40, y: 0)
        entityNode.addChild(player)

        companion = CompanionNode()
        companion.position = CGPoint(x: 80, y: 40)
        companion.browseTarget = interestPoints.randomElement()
        entityNode.addChild(companion)
    }

    override func update(_ currentTime: TimeInterval) {
        guard let session, session.outcome == nil else { return }
        if session.isGameplayFrozen {
            syncAimGhost(session: session)
            return
        }

        let dt: TimeInterval = 1.0 / 60.0
        elapsed += dt
        shoveSFXCooldown = max(0, shoveSFXCooldown - dt)

        updateTimer(dt: dt, session: session)
        updatePlayer(dt: dt, session: session)
        updateCompanion(dt: dt)
        updateClerks(dt: dt, session: session)
        pushClerksWithPlayer()
        updateBudgetDrain(dt: dt, session: session)
        updateSpawner(dt: dt, session: session)
        updateWeapons(dt: dt, session: session)
        syncPriceAura(session: session)
        updateProjectiles(dt: dt)
        updateCoupons(dt: dt, session: session)
        updateXPOrbs(dt: dt, session: session)
        updateCamera(dt: dt)
        updatePitchBanner(dt: dt, session: session)
        syncAimGhost(session: session)
        handleCouponDeploy(session: session)
    }

    // MARK: - Coupon aim (touch)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let session, session.isAimingCoupon, let touch = touches.first else { return }
        let point = touch.location(in: entityNode)
        session.couponAimWorld = clampPoint(point)
        syncAimGhost(session: session)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let session, session.isAimingCoupon, let touch = touches.first else { return }
        let point = touch.location(in: entityNode)
        session.couponAimWorld = clampPoint(point)
        syncAimGhost(session: session)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let session, session.isAimingCoupon else { return }
        if let touch = touches.first {
            session.couponAimWorld = clampPoint(touch.location(in: entityNode))
        }
        session.requestCouponDeploy()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        session?.cancelCouponAim()
        clearAimGhost()
    }

    private func syncAimGhost(session: GameSession) {
        guard session.isAimingCoupon else {
            clearAimGhost()
            return
        }
        let target = session.couponAimWorld ?? CGPoint(x: player.position.x + 80, y: player.position.y)
        if aimGhost == nil {
            let ghost = CouponNode()
            ghost.alpha = 0.55
            ghost.life = 999
            // Remove physics from ghost
            ghost.physicsBody = nil
            entityNode.addChild(ghost)
            aimGhost = ghost

            let place = SKLabelNode(fontNamed: "Menlo-Bold")
            place.text = "RELEASE TO DROP"
            place.fontSize = 10
            place.fontColor = .white
            place.position = CGPoint(x: 0, y: 36)
            place.zPosition = 5
            ghost.addChild(place)
        }
        aimGhost?.position = target
    }

    private func clearAimGhost() {
        aimGhost?.removeFromParent()
        aimGhost = nil
    }

    private func handleCouponDeploy(session: GameSession) {
        guard session.couponDeployRequested else { return }
        session.couponDeployRequested = false
        let point = session.couponAimWorld ?? CGPoint(x: player.position.x + 80, y: player.position.y)
        session.isAimingCoupon = false
        clearAimGhost()
        deployCoupon(at: clampPoint(point), session: session)
    }

    private func deployCoupon(at point: CGPoint, session: GameSession) {
        guard session.couponCooldown <= 0 else { return }
        session.couponCooldown = session.couponMaxCooldown

        let coupon = CouponNode()
        coupon.position = point
        entityNode.addChild(coupon)
        coupons.append(coupon)
        session.showToast("LURE dropped — clerks will flock to it")

        for clerk in clerks {
            let dist = hypot(clerk.position.x - coupon.position.x, clerk.position.y - coupon.position.y)
            if dist <= coupon.lureRadius {
                clerk.lureTarget = coupon.position
                clerk.lureTimeRemaining = 3.5
            }
        }
        AudioManager.shared.playSFX(.coupon)
    }

    // MARK: - Systems

    private func updateTimer(dt: TimeInterval, session: GameSession) {
        session.timeRemaining = max(0, session.timeRemaining - dt)
        if session.timeRemaining <= 0 {
            session.endRun(won: session.budget > 0, storeId: store.id)
        }
        if session.couponCooldown > 0 {
            session.couponCooldown = max(0, session.couponCooldown - dt)
        }
    }

    private func updatePlayer(dt: TimeInterval, session: GameSession) {
        let input = session.moveVector
        let len = hypot(input.dx, input.dy)
        // Joystick still steers while aiming a coupon (other thumb).
        let moving = len > 0.05
        if moving {
            let nx = input.dx / len
            let ny = input.dy / len
            player.facing = CGVector(dx: nx, dy: ny)
            let speed = player.baseSpeed * session.moveSpeedMultiplier
            let previous = player.position
            player.position.x += nx * speed * CGFloat(dt)
            player.position.y += ny * speed * CGFloat(dt)
            clampToArena(player)
            resolveShelfCollision(player, radius: 14, previous: previous)
        }
        player.walk.update(sprite: player, moving: moving, facingDX: player.facing.dx, dt: dt)
    }

    private func updateCompanion(dt: TimeInterval) {
        if companion.chatCooldown > 0 {
            companion.chatCooldown -= dt
        }

        if companion.browsePause > 0 {
            companion.browsePause -= dt
            companion.setStatus("browsing…")
            companion.walk.update(sprite: companion, moving: false, facingDX: companion.facingDX, dt: dt)
            return
        }

        if companion.browseTarget == nil || reached(companion.position, companion.browseTarget!) {
            beginCompanionBrowse()
            companion.walk.update(sprite: companion, moving: false, facingDX: companion.facingDX, dt: dt)
            return
        }

        guard let target = companion.browseTarget else { return }
        companion.facingDX = target.x - companion.position.x
        let beforeDist = hypot(target.x - companion.position.x, target.y - companion.position.y)
        moveCompanionToward(target, dt: dt)

        let afterDist = hypot(target.x - companion.position.x, target.y - companion.position.y)
        if afterDist < companion.lastProgressDist - 1.5 {
            companion.lastProgressDist = afterDist
            companion.stuckTimer = 0
        } else if afterDist >= beforeDist - 0.5 {
            companion.stuckTimer += dt
            if companion.stuckTimer > 1.4 {
                // Give up on unreachable / blocked targets and pick a new aisle.
                companion.browseTarget = nil
                companion.stuckTimer = 0
                companion.lastProgressDist = .greatestFiniteMagnitude
            }
        }

        companion.setStatus("shopping…")
        companion.walk.update(sprite: companion, moving: true, facingDX: companion.facingDX, dt: dt)
    }

    private func beginCompanionBrowse() {
        companion.browsePause = TimeInterval.random(in: 0.8...2.2)
        companion.browseTarget = pickCompanionInterestPoint()
        companion.stuckTimer = 0
        companion.lastProgressDist = .greatestFiniteMagnitude
        companion.setStatus("browsing…")
        maybeCompanionChat()
    }

    private func pickCompanionInterestPoint() -> CGPoint? {
        let options = interestPoints.filter { point in
            !reached(companion.position, point) && isWalkable(point, radius: 14)
        }
        if let pick = options.randomElement() { return pick }
        return interestPoints.filter { isWalkable($0, radius: 14) }.randomElement() ?? interestPoints.randomElement()
    }

    /// Direct move, then axis slides if a shelf blocks the path.
    private func moveCompanionToward(_ target: CGPoint, dt: TimeInterval) {
        let speed = companion.browseSpeed * CGFloat(dt)
        let dx = target.x - companion.position.x
        let dy = target.y - companion.position.y
        let dist = max(1, hypot(dx, dy))
        let previous = companion.position

        companion.position.x += dx / dist * speed
        companion.position.y += dy / dist * speed
        clampToArena(companion)
        resolveShelfCollision(companion, radius: 13, previous: previous)

        let moved = hypot(companion.position.x - previous.x, companion.position.y - previous.y)
        if moved >= speed * 0.35 { return }

        // Slide along the freer axis to go around shelf corners.
        let xDir: CGFloat = dx >= 0 ? 1 : -1
        let yDir: CGFloat = dy >= 0 ? 1 : -1

        companion.position = previous
        companion.position.x += xDir * speed
        clampToArena(companion)
        resolveShelfCollision(companion, radius: 13, previous: previous)
        let afterX = companion.position
        let movedX = abs(afterX.x - previous.x)

        companion.position = previous
        companion.position.y += yDir * speed
        clampToArena(companion)
        resolveShelfCollision(companion, radius: 13, previous: previous)
        let afterY = companion.position
        let movedY = abs(afterY.y - previous.y)

        if movedX >= movedY, movedX > 0.5 {
            companion.position = afterX
        } else if movedY > 0.5 {
            companion.position = afterY
        } else {
            companion.position = previous
        }
    }

    private func maybeCompanionChat() {
        guard companion.chatCooldown <= 0 else { return }
        guard Double.random(in: 0...1) < 0.72 else { return }
        guard let line = CompanionNode.shoppingLines.randomElement() else { return }
        companion.chatCooldown = TimeInterval.random(in: 3.5...6.5)
        spawnCompanionChat(line, at: companion.position)
        AudioManager.shared.playSFX(.companion, volume: 0.65)
    }

    private func reached(_ a: CGPoint, _ b: CGPoint) -> Bool {
        hypot(a.x - b.x, a.y - b.y) < 18
    }

    private func isWalkable(_ point: CGPoint, radius: CGFloat) -> Bool {
        for rect in shelfRects {
            let nearestX = min(max(point.x, rect.minX), rect.maxX)
            let nearestY = min(max(point.y, rect.minY), rect.maxY)
            let dx = point.x - nearestX
            let dy = point.y - nearestY
            if dx * dx + dy * dy < radius * radius {
                return false
            }
        }
        return true
    }

    private func updateClerks(dt: TimeInterval, session: GameSession) {
        for clerk in clerks {
            var moving = false
            var facing: CGFloat = clerk.facingDX

            if clerk.lureTimeRemaining > 0, let lure = clerk.lureTarget {
                clerk.lureTimeRemaining -= dt
                let before = clerk.position
                moveClerk(clerk, toward: lure, speed: clerk.clerkType.moveSpeed * 1.15, dt: dt)
                facing = clerk.position.x - before.x
                moving = true
                if clerk.lureTimeRemaining <= 0 {
                    clerk.lureTarget = nil
                }
            } else {
                let before = clerk.position
                moveClerk(clerk, toward: companion.position, speed: clerk.clerkType.moveSpeed, dt: dt)
                facing = clerk.position.x - before.x
                moving = hypot(clerk.position.x - before.x, clerk.position.y - before.y) > 0.2
            }

            if clerk.knockbackVelocity.dx != 0 || clerk.knockbackVelocity.dy != 0 {
                let previous = clerk.position
                clerk.position.x += clerk.knockbackVelocity.dx * CGFloat(dt)
                clerk.position.y += clerk.knockbackVelocity.dy * CGFloat(dt)
                clerk.knockbackVelocity.dx *= 0.85
                clerk.knockbackVelocity.dy *= 0.85
                if hypot(clerk.knockbackVelocity.dx, clerk.knockbackVelocity.dy) < 5 {
                    clerk.knockbackVelocity = .zero
                }
                resolveShelfCollision(clerk, radius: 12, previous: previous)
                moving = true
            }
            clampToArena(clerk)
            clerk.facingDX = facing
            clerk.pitchCooldown = max(0, clerk.pitchCooldown - dt)
            clerk.walk.update(sprite: clerk, moving: moving, facingDX: clerk.facingDX, dt: dt)
        }
    }

    private func pushClerksWithPlayer() {
        let pushRadius: CGFloat = 30
        var shoved = false
        for clerk in clerks {
            let dx = clerk.position.x - player.position.x
            let dy = clerk.position.y - player.position.y
            let dist = hypot(dx, dy)
            guard dist < pushRadius, dist > 0.1 else { continue }
            let strength: CGFloat = 260
            clerk.knockbackVelocity = CGVector(dx: dx / dist * strength, dy: dy / dist * strength)
            shoved = true
        }
        if shoved, shoveSFXCooldown <= 0 {
            AudioManager.shared.playSFX(.shove, volume: 0.7)
            shoveSFXCooldown = 0.2
        }
    }

    private func moveClerk(_ clerk: ClerkNode, toward target: CGPoint, speed: CGFloat, dt: TimeInterval) {
        let dx = target.x - clerk.position.x
        let dy = target.y - clerk.position.y
        let dist = hypot(dx, dy)
        guard dist > 4 else { return }
        let previous = clerk.position
        clerk.position.x += dx / dist * speed * CGFloat(dt)
        clerk.position.y += dy / dist * speed * CGFloat(dt)
        resolveShelfCollision(clerk, radius: 12, previous: previous)
    }

    private func updateBudgetDrain(dt: TimeInterval, session: GameSession) {
        var totalDrain: CGFloat = 0
        var pitchLine: String?

        for clerk in clerks {
            let dist = hypot(clerk.position.x - companion.position.x, clerk.position.y - companion.position.y)
            guard dist <= clerk.clerkType.pitchRadius else { continue }

            var rate = clerk.clerkType.drainPerSecond
            if clerk.clerkType == .upseller {
                let nearby = clerks.contains {
                    $0 !== clerk &&
                    hypot($0.position.x - clerk.position.x, $0.position.y - clerk.position.y) < 70
                }
                if nearby { rate *= clerk.clerkType.packBonus }
            }
            rate *= session.willpowerMultiplier
            totalDrain += rate * CGFloat(dt)

            if clerk.pitchCooldown <= 0 {
                pitchLine = clerk.clerkType.pitchLines.randomElement()
                clerk.pitchCooldown = TimeInterval.random(in: 1.8...3.2)
                spawnPitchLabel(pitchLine ?? "Sale!", at: clerk.position)
                AudioManager.shared.playSFX(.pitch, volume: 0.55)
                AudioManager.shared.playSFX(SFX.clerkVoice(clerk.clerkType), volume: 0.7)
            }
        }

        if totalDrain > 0 {
            session.budget = max(0, session.budget - totalDrain)
            if totalDrain > 0.08 {
                session.lastDrainFlash.toggle()
                shakeTime = 0.12
            }
            if let line = pitchLine {
                session.pitchBanner = line
                pitchBannerTimer = 1.4
            }
            if session.budget <= 0 {
                session.endRun(won: false, storeId: store.id)
            }
        }
    }

    private func updateSpawner(dt: TimeInterval, session: GameSession) {
        guard clerks.count < store.maxClerks else { return }
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnTimer = store.spawnInterval(at: elapsed)
            spawnClerk(type: store.weightedClerk())
            if elapsed / store.duration > 0.55, Bool.random() {
                spawnClerk(type: store.weightedClerk())
            }
        }
    }

    private func spawnClerk(type: ClerkType) {
        let clerk = ClerkNode(type: type)
        let edge = Int.random(in: 0...3)
        let halfW = arenaSize.width / 2 - 20
        let halfH = arenaSize.height / 2 - 20
        switch edge {
        case 0: clerk.position = CGPoint(x: CGFloat.random(in: -halfW...halfW), y: halfH)
        case 1: clerk.position = CGPoint(x: CGFloat.random(in: -halfW...halfW), y: -halfH)
        case 2: clerk.position = CGPoint(x: halfW, y: CGFloat.random(in: -halfH...halfH))
        default: clerk.position = CGPoint(x: -halfW, y: CGFloat.random(in: -halfH...halfH))
        }
        entityNode.addChild(clerk)
        clerks.append(clerk)
    }

    private func updateWeapons(dt: TimeInterval, session: GameSession) {
        for weapon in session.weapons {
            let cd = weaponCooldowns[weapon.kind, default: 0] - dt
            weaponCooldowns[weapon.kind] = cd
            guard cd <= 0 else { continue }
            weaponCooldowns[weapon.kind] = weapon.kind.cooldown(level: weapon.level)
            fireWeapon(weapon, session: session)
        }
    }

    private func syncPriceAura(session: GameSession) {
        guard let owned = session.weapons.first(where: { $0.kind == .priceTags }) else {
            priceAuraRing?.removeFromParent()
            priceAuraRing = nil
            priceAuraRadius = 0
            return
        }
        let radius = owned.kind.auraRadius(level: owned.level)
        if priceAuraRing == nil {
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.strokeColor = SKColor(red: 0.35, green: 0.9, blue: 0.95, alpha: 0.55)
            ring.lineWidth = 2
            ring.fillColor = SKColor(red: 0.3, green: 0.85, blue: 0.95, alpha: 0.1)
            ring.zPosition = 18
            ring.name = "priceAura"
            entityNode.addChild(ring)
            priceAuraRing = ring
            priceAuraRadius = radius
            ring.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.55, duration: 0.55),
                SKAction.fadeAlpha(to: 0.9, duration: 0.55)
            ])))
        } else if abs(priceAuraRadius - radius) > 0.5 {
            priceAuraRing?.path = CGPath(
                ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                transform: nil
            )
            priceAuraRadius = radius
        }
        priceAuraRing?.position = player.position
    }

    private func fireWeapon(_ owned: OwnedWeapon, session: GameSession) {
        let dmg = owned.kind.damage(level: owned.level)
        switch owned.kind {
        case .priceTags:
            let radius = owned.kind.auraRadius(level: owned.level)
            for clerk in clerks {
                let dist = hypot(clerk.position.x - player.position.x, clerk.position.y - player.position.y)
                if dist <= radius {
                    hitClerk(clerk, damage: dmg, from: player.position, session: session, knockbackStrength: 90)
                }
            }

        case .receipts:
            let targets = nearestClerks(count: min(1 + owned.level / 2, 3))
            for target in targets {
                let proj = ProjectileNode(weapon: .receipts, damage: dmg, life: 1.0, pierce: 1)
                proj.position = player.position
                let dx = target.position.x - player.position.x
                let dy = target.position.y - player.position.y
                let dist = max(1, hypot(dx, dy))
                proj.physicsBody?.velocity = CGVector(dx: dx / dist * 320, dy: dy / dist * 320)
                proj.zRotation = atan2(dy, dx)
                entityNode.addChild(proj)
                projectiles.append(proj)
            }

        case .barcodeLaser:
            let facing = player.facing
            let length: CGFloat = 180 + CGFloat(owned.level) * 20
            let proj = ProjectileNode(weapon: .barcodeLaser, damage: dmg, life: 0.25, pierce: 99)
            proj.size = CGSize(width: length, height: 12)
            proj.anchorPoint = CGPoint(x: 0, y: 0.5)
            proj.position = player.position
            proj.zRotation = atan2(facing.dy, facing.dx)
            entityNode.addChild(proj)
            projectiles.append(proj)
            for clerk in clerks {
                if pointNearSegment(
                    clerk.position,
                    a: player.position,
                    b: CGPoint(x: player.position.x + facing.dx * length, y: player.position.y + facing.dy * length),
                    threshold: 22
                ) {
                    hitClerk(clerk, damage: dmg, from: player.position, session: session)
                }
            }

        case .shoppingBag:
            let radius: CGFloat = 70 + CGFloat(owned.level) * 10
            let pulse = SKShapeNode(circleOfRadius: radius)
            pulse.strokeColor = SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.8)
            pulse.fillColor = SKColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.15)
            pulse.lineWidth = 3
            pulse.position = player.position
            pulse.zPosition = 24
            entityNode.addChild(pulse)
            pulse.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.35),
                    SKAction.scale(to: 1.3, duration: 0.35)
                ]),
                SKAction.removeFromParent()
            ]))
            for clerk in clerks {
                let dist = hypot(clerk.position.x - player.position.x, clerk.position.y - player.position.y)
                if dist <= radius {
                    hitClerk(clerk, damage: dmg, from: player.position, session: session, knockbackStrength: 280)
                }
            }
        }
    }

    private func updateProjectiles(dt: TimeInterval) {
        guard let session else {
            projectiles.forEach { $0.removeFromParent() }
            projectiles.removeAll()
            return
        }
        var keep: [ProjectileNode] = []
        for proj in projectiles {
            proj.life -= dt
            if proj.life <= 0 || proj.pierceLeft <= 0 {
                proj.removeFromParent()
                continue
            }
            if proj.weapon == .receipts {
                for clerk in clerks {
                    let dist = hypot(clerk.position.x - proj.position.x, clerk.position.y - proj.position.y)
                    if dist < 20 {
                        hitClerk(clerk, damage: proj.damage, from: proj.position, session: session)
                        proj.pierceLeft -= 1
                        break
                    }
                }
            }
            if proj.pierceLeft > 0 && proj.life > 0 && proj.parent != nil {
                keep.append(proj)
            } else {
                proj.removeFromParent()
            }
        }
        projectiles = keep
    }

    private func updateCoupons(dt: TimeInterval, session: GameSession) {
        var keep: [CouponNode] = []
        for coupon in coupons {
            coupon.life -= dt
            if coupon.life <= 0 {
                coupon.removeFromParent()
            } else {
                for clerk in clerks where clerk.lureTarget == nil {
                    let dist = hypot(clerk.position.x - coupon.position.x, clerk.position.y - coupon.position.y)
                    if dist <= coupon.lureRadius {
                        clerk.lureTarget = coupon.position
                        clerk.lureTimeRemaining = min(3.0, coupon.life)
                    }
                }
                keep.append(coupon)
            }
        }
        coupons = keep
    }

    private func updateXPOrbs(dt: TimeInterval, session: GameSession) {
        let magnetRange: CGFloat = 70 + CGFloat(session.playerLevel) * 4
        var keep: [XPOrbNode] = []
        for orb in xpOrbs {
            let dx = player.position.x - orb.position.x
            let dy = player.position.y - orb.position.y
            let dist = hypot(dx, dy)
            if dist < 22 {
                gainXP(orb.amount, session: session)
                session.showToast("+\(orb.amount) XP")
                AudioManager.shared.playSFX(.xp)
                orb.removeFromParent()
            } else if dist < magnetRange {
                orb.position.x += dx / dist * 220 * CGFloat(dt)
                orb.position.y += dy / dist * 220 * CGFloat(dt)
                keep.append(orb)
            } else {
                keep.append(orb)
            }
        }
        xpOrbs = keep
    }

    private func hitClerk(
        _ clerk: ClerkNode,
        damage: CGFloat,
        from: CGPoint,
        session: GameSession,
        knockbackStrength: CGFloat = 160
    ) {
        let dx = clerk.position.x - from.x
        let dy = clerk.position.y - from.y
        let dist = max(1, hypot(dx, dy))
        let kb = CGVector(dx: dx / dist * knockbackStrength, dy: dy / dist * knockbackStrength)
        clerk.applyDamage(damage, knockback: kb)
        AudioManager.shared.playSFX(.hit, volume: 0.55)
        if clerk.hp <= 0 {
            defeatClerk(clerk, session: session)
        }
    }

    private func defeatClerk(_ clerk: ClerkNode, session: GameSession) {
        guard let idx = clerks.firstIndex(where: { $0 === clerk }) else { return }
        clerks.remove(at: idx)
        AudioManager.shared.playSFX(.defeat)

        let orb = XPOrbNode(amount: clerk.clerkType.xpReward)
        orb.position = clerk.position
        entityNode.addChild(orb)
        xpOrbs.append(orb)

        clerk.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.scale(to: 0.3, duration: 0.15)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func gainXP(_ amount: Int, session: GameSession) {
        session.xp += amount
        while session.xp >= session.xpToNext {
            session.xp -= session.xpToNext
            session.playerLevel += 1
            session.xpToNext = Int(12 + Double(session.playerLevel) * 7.5)
            let offers = generateUpgradeOffers(session: session)
            session.presentUpgrades(offers)
        }
    }

    private func generateUpgradeOffers(session: GameSession) -> [UpgradeOffer] {
        var pool: [UpgradeOffer] = [
            UpgradeOffer(kind: .moveSpeed),
            UpgradeOffer(kind: .couponCooldown),
            UpgradeOffer(kind: .willpower),
            UpgradeOffer(kind: .budgetRefill)
        ]
        for w in session.weapons {
            pool.append(UpgradeOffer(kind: .weaponLevel, weapon: w.kind))
        }
        let owned = Set(session.weapons.map(\.kind))
        for kind in WeaponKind.allCases where !owned.contains(kind) {
            pool.append(UpgradeOffer(kind: .unlockWeapon, weapon: kind))
        }
        return Array(pool.shuffled().prefix(3))
    }

    private func nearestClerks(count: Int) -> [ClerkNode] {
        clerks
            .map { ($0, hypot($0.position.x - player.position.x, $0.position.y - player.position.y)) }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map(\.0)
    }

    private func updateCamera(dt: TimeInterval) {
        let target = player.position
        let blend: CGFloat = 0.12
        cameraNode.position.x += (target.x - cameraNode.position.x) * blend
        cameraNode.position.y += (target.y - cameraNode.position.y) * blend

        if shakeTime > 0 {
            shakeTime -= dt
            cameraNode.position.x += CGFloat.random(in: -3...3)
            cameraNode.position.y += CGFloat.random(in: -3...3)
        }

        session?.cameraWorldPosition = cameraNode.position
    }

    private func updatePitchBanner(dt: TimeInterval, session: GameSession) {
        if pitchBannerTimer > 0 {
            pitchBannerTimer -= dt
            if pitchBannerTimer <= 0 {
                session.pitchBanner = ""
            }
        }
    }

    private func spawnPitchLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 14
        label.fontColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        label.position = CGPoint(x: position.x, y: position.y + 24)
        label.zPosition = 40
        entityNode.addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 0.8),
                SKAction.fadeOut(withDuration: 0.8)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func spawnCompanionChat(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 12
        label.fontColor = SKColor(red: 1.0, green: 0.72, blue: 0.55, alpha: 1)
        label.position = CGPoint(x: position.x, y: position.y + 28)
        label.zPosition = 41
        entityNode.addChild(label)
        label.setScale(0.85)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.05, duration: 0.12),
                SKAction.moveBy(x: 0, y: 36, duration: 1.15)
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 10, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func clampToArena(_ node: SKNode) {
        node.position = clampPoint(node.position)
    }

    /// Push a circular body out of shelf rectangles (manual movement, not physics-driven).
    private func resolveShelfCollision(_ node: SKNode, radius: CGFloat, previous: CGPoint) {
        var p = node.position
        for rect in shelfRects {
            let nearestX = min(max(p.x, rect.minX), rect.maxX)
            let nearestY = min(max(p.y, rect.minY), rect.maxY)
            let dx = p.x - nearestX
            let dy = p.y - nearestY
            let distSq = dx * dx + dy * dy
            if distSq < radius * radius {
                if distSq < 0.001 {
                    // Center inside shelf — revert axis that penetrated least from previous
                    p = previous
                } else {
                    let dist = sqrt(distSq)
                    let push = (radius - dist) / dist
                    p.x += dx * push
                    p.y += dy * push
                }
            }
        }
        node.position = p
        clampToArena(node)
    }

    private func clampPoint(_ p: CGPoint) -> CGPoint {
        let m: CGFloat = 24
        return CGPoint(
            x: min(max(p.x, -arenaSize.width / 2 + m), arenaSize.width / 2 - m),
            y: min(max(p.y, -arenaSize.height / 2 + m), arenaSize.height / 2 - m)
        )
    }

    private func pointNearSegment(_ p: CGPoint, a: CGPoint, b: CGPoint, threshold: CGFloat) -> Bool {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y
        let abLen2 = abx * abx + aby * aby
        guard abLen2 > 0 else { return hypot(apx, apy) < threshold }
        let t = max(0, min(1, (apx * abx + apy * aby) / abLen2))
        let cx = a.x + abx * t
        let cy = a.y + aby * t
        return hypot(p.x - cx, p.y - cy) < threshold
    }

    func didBegin(_ contact: SKPhysicsContact) {}
}
