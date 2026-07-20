import GameController
import SpriteKit
import SwiftUI
import UIKit

@MainActor
final class GameScene: SKScene {
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
    private var shelfGrid = SpatialGrid(cellSize: 128)
    private var clerkGrid = SpatialGrid(cellSize: 64)
    private var clerkUpdateParity = 0
    private var nameTagsVisible = true

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
    private var controllerConnectObserver: NSObjectProtocol?
    private var lastUpdateTime: TimeInterval = 0
    private var hitFeedbackCooldown: TimeInterval = 0
    private var defeatSFXCooldown: TimeInterval = 0
    private var hudPublishAccumulator: TimeInterval = 0
    private var couponLureScanAccum: TimeInterval = 0
    private var walkableInterestPoints: [CGPoint] = []
    private var weaponHitBuffer: [ClerkNode] = []
    private weak var skView: SKView?
    private var fpsLastTime: TimeInterval = 0
    private var fpsFrameCount = 0
    private var fpsAccum: TimeInterval = 0

    func configure(session: GameSession, store: StoreLevel) {
        self.session = session
        self.store = store
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(store.floorColor)
        physicsWorld.gravity = .zero
        isUserInteractionEnabled = true
        lastUpdateTime = 0
        fpsLastTime = 0
        fpsFrameCount = 0
        fpsAccum = 0
        skView = view
        view.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        view.ignoresSiblingOrder = true

        addChild(worldNode)
        worldNode.addChild(entityNode)

        buildArena()
        spawnPlayerAndCompanion()

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = player.position

        setupControllerHandlers()
        controllerConnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setupControllerHandlers() }
        }
    }

    override func willMove(from view: SKView) {
        if let controllerConnectObserver {
            NotificationCenter.default.removeObserver(controllerConnectObserver)
            self.controllerConnectObserver = nil
        }
        lastUpdateTime = 0
        fpsLastTime = 0
        fpsFrameCount = 0
        fpsAccum = 0
    }

    private func buildArena() {
        interestPoints.removeAll()
        shelfRects.removeAll()
        shelfGrid.clear()
        walkableInterestPoints.removeAll()

        let floorTexture = makeFloorTexture()
        let floor = SKSpriteNode(texture: floorTexture, size: arenaSize)
        floor.zPosition = -10
        worldNode.addChild(floor)

        let shelfTarget = store.shelfCount
        var placed = 0
        var attempts = 0
        while placed < shelfTarget && attempts < shelfTarget * 8 {
            attempts += 1
            let prop = SKSpriteNode(imageNamed: "prop_shelf")
            prop.texture?.filteringMode = .nearest
            let scale: CGFloat = store.id == "fashion" ? 0.9 : (store.id == "grocery" ? 1.15 : 1.0)
            let shelfSize = CGSize(width: 56 * scale, height: 36 * scale)
            prop.size = shelfSize
            let pos: CGPoint
            if store.id == "electronics" {
                // Grid-ish aisles
                let col = CGFloat((placed % 4) - 1) * 180 + CGFloat.random(in: -20...20)
                let row = CGFloat((placed / 4) - 1) * 140 + CGFloat.random(in: -16...16)
                pos = CGPoint(x: col, y: row)
            } else {
                pos = CGPoint(
                    x: CGFloat.random(in: -arenaSize.width / 2 + 100...arenaSize.width / 2 - 100),
                    y: CGFloat.random(in: -arenaSize.height / 2 + 100...arenaSize.height / 2 - 100)
                )
            }
            if hypot(pos.x, pos.y) < 160 { continue }
            prop.position = pos
            prop.zPosition = -5
            prop.color = UIColor(store.accentColor)
            prop.colorBlendFactor = store.isEndless ? 0.4 : 0.25
            worldNode.addChild(prop)
            placed += 1

            let inset: CGFloat = 4
            let rect = CGRect(
                x: pos.x - shelfSize.width / 2 + inset,
                y: pos.y - shelfSize.height / 2 + inset,
                width: shelfSize.width - inset * 2,
                height: shelfSize.height - inset * 2
            )
            shelfRects.append(rect)
            shelfGrid.insert(shelfRects.count - 1, at: CGPoint(x: rect.midX, y: rect.midY))

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
        walkableInterestPoints = interestPoints

        let border = SKShapeNode(rectOf: arenaSize)
        border.strokeColor = UIColor(store.accentColor).withAlphaComponent(0.6)
        border.lineWidth = 4
        border.fillColor = .clear
        border.zPosition = -8
        worldNode.addChild(border)
    }

    /// Bake checkerboard / floor tiles into one texture to cut hundreds of scene nodes.
    private func makeFloorTexture() -> SKTexture {
        let size = arenaSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let accent = UIColor(store.accentColor)
        let tileTint = accent.withAlphaComponent(store.isEndless ? 0.25 : 0.16)
        let floorTile = UIImage(named: "floor_tile")
        let image = renderer.image { ctx in
            UIColor(store.floorColor).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let tileSize: CGFloat = 64
            let cols = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(c) * tileSize,
                        y: CGFloat(r) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    if (r + c) % 3 == 0 {
                        floorTile?.draw(in: rect, blendMode: .normal, alpha: 0.55)
                        tileTint.setFill()
                        ctx.fill(rect)
                    } else if (r + c) % 2 != 0 {
                        accent.withAlphaComponent(0.08).setFill()
                        ctx.fill(rect)
                    }
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
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
        sampleFPS(currentTime: currentTime, session: session)
        if GameControllerManager.shared.isConnected {
            GameControllerManager.shared.pollMovement(into: session)
        }
        if GCKeyboard.coalesced != nil {
            GameControllerManager.shared.pollKeyboard(into: session)
        }
        if session.isGameplayFrozen {
            lastUpdateTime = currentTime
            syncAimGhost(session: session)
            return
        }

        let rawDt: TimeInterval
        if lastUpdateTime == 0 {
            rawDt = 1.0 / 60.0
        } else {
            rawDt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        // Clamp so background hitch / debugger pause doesn't explode simulation.
        let dt = min(max(rawDt, 0), 1.0 / 20.0)

        elapsed += dt
        session.runElapsed = elapsed
        shoveSFXCooldown = max(0, shoveSFXCooldown - dt)
        hitFeedbackCooldown = max(0, hitFeedbackCooldown - dt)
        defeatSFXCooldown = max(0, defeatSFXCooldown - dt)
        hudPublishAccumulator += dt

        updateTimer(dt: dt, session: session)
        updatePlayer(dt: dt, session: session)
        updateCompanion(dt: dt)
        updateClerks(dt: dt, session: session)
        separateClerks()
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

        if hudPublishAccumulator >= 1.0 / 12.0 {
            hudPublishAccumulator = 0
            session.publishHUD()
        }
    }

    private func sampleFPS(currentTime: TimeInterval, session: GameSession) {
        guard session.showFPS else {
            if fpsLastTime != 0 {
                fpsLastTime = 0
                fpsFrameCount = 0
                fpsAccum = 0
                skView?.showsNodeCount = false
                skView?.showsDrawCount = false
            }
            return
        }
        if fpsLastTime == 0 {
            skView?.showsNodeCount = true
            skView?.showsDrawCount = true
        }
        if fpsLastTime == 0 {
            fpsLastTime = currentTime
            return
        }
        let frameDt = currentTime - fpsLastTime
        fpsLastTime = currentTime
        // Ignore debugger / background gaps so the counter doesn't spike to 1–2 FPS.
        guard frameDt > 0, frameDt < 1.0 else { return }
        fpsFrameCount += 1
        fpsAccum += frameDt
        if fpsAccum >= 0.5 {
            session.displayedFPS = max(0, Int((Double(fpsFrameCount) / fpsAccum).rounded()))
            session.displayedNodeCount = entityNode.children.count
            fpsFrameCount = 0
            fpsAccum = 0
            session.publishHUD()
        }
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
        session.publishHUD(force: true)

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
        session.noteLureDeployed()
        Haptics.ui()
    }

    // MARK: - Controller Support

    private func setupControllerHandlers() {
        guard session != nil,
              let pad = GCController.controllers().first?.extendedGamepad else { return }

        // A / Cross → deploy a coupon lure ahead of the player
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in
                guard let self, let session = self.session else { return }
                guard session.couponCooldown <= 0,
                      session.outcome == nil,
                      !session.isPausedForUpgrade,
                      !session.isPaused,
                      !session.isTutorialActive else { return }
                let forward = self.player.facing
                let point = CGPoint(
                    x: self.player.position.x + forward.dx * 80,
                    y: self.player.position.y + forward.dy * 80
                )
                self.deployCoupon(at: self.clampPoint(point), session: session)
            }
        }

        // Menu / Options → toggle pause
        pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in
                self?.session?.togglePause()
            }
        }
    }

    // MARK: - Systems

    private func updateTimer(dt: TimeInterval, session: GameSession) {
        if store.isEndless {
            // Endless: survive until budget hits 0 — no timed win.
            session.timeRemaining = elapsed
        } else {
            session.timeRemaining = max(0, session.timeRemaining - dt)
            if session.timeRemaining <= 0 {
                session.publishHUD(force: true)
                session.endRun(won: session.budget > 0, storeId: store.id)
            }
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
        let options = walkableInterestPoints.filter { !reached(companion.position, $0) }
        if let pick = options.randomElement() { return pick }
        return walkableInterestPoints.randomElement()
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
        if session?.reducedFX != true {
            spawnCompanionChat(line, at: companion.position)
        }
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
        clerkUpdateParity ^= 1
        let companionPos = companion.position
        // Clerks farther than this from the friend update on alternating frames.
        let nearRadiusSq: CGFloat = 320 * 320
        let crowded = clerks.count >= 28

        for (index, clerk) in clerks.enumerated() {
            let dxC = clerk.position.x - companionPos.x
            let dyC = clerk.position.y - companionPos.y
            let distToFriendSq = dxC * dxC + dyC * dyC
            let isNear = distToFriendSq <= nearRadiusSq
            let hasKnockback = clerk.knockbackVelocity.dx != 0 || clerk.knockbackVelocity.dy != 0

            // Far idle-ish clerks: half-rate sim with 2× step (keeps average speed).
            if crowded, !isNear, !hasKnockback, (index & 1) != clerkUpdateParity {
                clerk.pitchCooldown = max(0, clerk.pitchCooldown - dt)
                continue
            }
            let stepDt = (crowded && !isNear && !hasKnockback) ? dt * 2 : dt

            var moving = false
            var facing: CGFloat = clerk.facingDX

            if clerk.lureTimeRemaining > 0, let lure = clerk.lureTarget {
                clerk.lureTimeRemaining -= stepDt
                let before = clerk.position
                moveClerk(clerk, toward: lure, speed: clerk.clerkType.moveSpeed * 1.15, dt: stepDt)
                facing = clerk.position.x - before.x
                moving = true
                if clerk.lureTimeRemaining <= 0 {
                    clerk.lureTarget = nil
                }
            } else {
                let before = clerk.position
                moveClerk(clerk, toward: companionPos, speed: clerk.clerkType.moveSpeed, dt: stepDt)
                facing = clerk.position.x - before.x
                let mdx = clerk.position.x - before.x
                let mdy = clerk.position.y - before.y
                moving = mdx * mdx + mdy * mdy > 0.04
            }

            if hasKnockback {
                let previous = clerk.position
                clerk.position.x += clerk.knockbackVelocity.dx * CGFloat(stepDt)
                clerk.position.y += clerk.knockbackVelocity.dy * CGFloat(stepDt)
                clerk.knockbackVelocity.dx *= 0.85
                clerk.knockbackVelocity.dy *= 0.85
                let kvx = clerk.knockbackVelocity.dx
                let kvy = clerk.knockbackVelocity.dy
                if kvx * kvx + kvy * kvy < 25 {
                    clerk.knockbackVelocity = .zero
                }
                resolveShelfCollision(clerk, radius: 12, previous: previous)
                moving = true
            }
            clampToArena(clerk)
            clerk.facingDX = facing
            clerk.pitchCooldown = max(0, clerk.pitchCooldown - stepDt)
            if clerk.colorBlendFactor > 0 {
                clerk.colorBlendFactor = max(0, clerk.colorBlendFactor - CGFloat(stepDt) * 6)
            }
            // Skip walk anim swaps for far clerks when crowded — big texture upload savings.
            if isNear || !crowded {
                clerk.walk.update(sprite: clerk, moving: moving, facingDX: clerk.facingDX, dt: stepDt)
            }
        }
    }

    /// Soft push via spatial grid (near-linear). Also marks upseller pack neighbors.
    private func separateClerks() {
        let count = clerks.count
        guard count > 1 else {
            clerks.first?.hasPackNeighbor = false
            return
        }

        let minDist: CGFloat = 20
        let minDistSq = minDist * minDist
        let packDistSq: CGFloat = 70 * 70

        for clerk in clerks {
            clerk.hasPackNeighbor = false
        }

        clerkGrid.rebuild(count: count) { clerks[$0].position }

        // cellSize 64 → radius 2 covers pack distance (~70).
        for i in 0..<count {
            let a = clerks[i]
            let ap = a.position
            clerkGrid.forEachNearby(to: ap, cellsRadius: 2) { j in
                guard j > i else { return }
                let b = clerks[j]
                let dx = b.position.x - ap.x
                let dy = b.position.y - ap.y
                let distSq = dx * dx + dy * dy
                guard distSq < packDistSq else { return }

                if a.clerkType == .upseller { a.hasPackNeighbor = true }
                if b.clerkType == .upseller { b.hasPackNeighbor = true }

                guard distSq < minDistSq else { return }
                if distSq < 0.01 {
                    a.position.x -= 1
                    b.position.x += 1
                    return
                }
                let dist = sqrt(distSq)
                let push = (minDist - dist) * 0.5
                let nx = dx / dist
                let ny = dy / dist
                a.position.x -= nx * push
                a.position.y -= ny * push
                b.position.x += nx * push
                b.position.y += ny * push
            }
        }
    }

    private func pushClerksWithPlayer() {
        let pushRadius: CGFloat = 30
        let pushRadiusSq = pushRadius * pushRadius
        var shoved = false
        let px = player.position.x
        let py = player.position.y
        // Reuse clerk grid from separation when available; rebuild if empty.
        if clerkGrid.buckets.isEmpty, !clerks.isEmpty {
            clerkGrid.rebuild(count: clerks.count) { clerks[$0].position }
        }
        clerkGrid.forEachNearby(to: player.position, cellsRadius: 1) { index in
            let clerk = clerks[index]
            let dx = clerk.position.x - px
            let dy = clerk.position.y - py
            let distSq = dx * dx + dy * dy
            guard distSq < pushRadiusSq, distSq > 0.01 else { return }
            let dist = sqrt(distSq)
            let strength: CGFloat = 260
            clerk.knockbackVelocity = CGVector(dx: dx / dist * strength, dy: dy / dist * strength)
            shoved = true
        }
        if shoved, shoveSFXCooldown <= 0 {
            AudioManager.shared.playSFX(.shove, volume: 0.7)
            Haptics.shove()
            shoveSFXCooldown = 0.2
        }
    }

    private func moveClerk(_ clerk: ClerkNode, toward target: CGPoint, speed: CGFloat, dt: TimeInterval) {
        let dx = target.x - clerk.position.x
        let dy = target.y - clerk.position.y
        let distSq = dx * dx + dy * dy
        guard distSq > 16 else { return }
        let dist = sqrt(distSq)
        let previous = clerk.position
        clerk.position.x += dx / dist * speed * CGFloat(dt)
        clerk.position.y += dy / dist * speed * CGFloat(dt)
        resolveShelfCollision(clerk, radius: 12, previous: previous)
    }

    private func updateBudgetDrain(dt: TimeInterval, session: GameSession) {
        var totalDrain: CGFloat = 0
        var pitchLine: String?
        let cx = companion.position.x
        let cy = companion.position.y

        // Reuse the clerk grid built by separateClerks this frame (cellSize 64 > max pitch radius 55).
        ensureClerkGrid()
        clerkGrid.forEachNearby(to: companion.position, cellsRadius: 1) { index in
            let clerk = clerks[index]
            let dx = clerk.position.x - cx
            let dy = clerk.position.y - cy
            let radius = clerk.clerkType.pitchRadius
            guard dx * dx + dy * dy <= radius * radius else { return }

            var rate = clerk.clerkType.drainPerSecond
            if clerk.clerkType == .upseller, clerk.hasPackNeighbor {
                rate *= clerk.clerkType.packBonus
            }
            rate *= session.willpowerMultiplier
            totalDrain += rate * CGFloat(dt)

            if clerk.pitchCooldown <= 0 {
                pitchLine = clerk.clerkType.pitchLines.randomElement()
                clerk.pitchCooldown = TimeInterval.random(in: 1.8...3.2)
                if !session.reducedFX {
                    spawnPitchLabel(pitchLine ?? "Sale!", at: clerk.position)
                }
                AudioManager.shared.playSFX(.pitch, volume: 0.55)
                AudioManager.shared.playSFX(SFX.clerkVoice(clerk.clerkType), volume: 0.7)
            }
        }

        if totalDrain > 0 {
            session.budget = max(0, session.budget - totalDrain)
            if totalDrain > 0.08 {
                if !session.reducedFX {
                    shakeTime = 0.12
                }
            }
            if let line = pitchLine {
                session.pitchBanner = line
                pitchBannerTimer = 1.4
            }
            if session.budget <= 0 {
                session.publishHUD(force: true)
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
            if store.difficultyProgress(elapsed: elapsed) > 0.55, Bool.random() {
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
        refreshClerkNameTagsIfNeeded()
        clerk.setNameTagHidden(!shouldShowClerkNameTags)
    }

    private var shouldShowClerkNameTags: Bool {
        clerks.count < 24 && session?.reducedFX != true
    }

    private func refreshClerkNameTagsIfNeeded() {
        let show = shouldShowClerkNameTags
        guard show != nameTagsVisible else { return }
        nameTagsVisible = show
        for clerk in clerks {
            clerk.setNameTagHidden(!show)
        }
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
        playWeaponFireSFX(owned.kind)
        switch owned.kind {
        case .priceTags:
            let radius = owned.kind.auraRadius(level: owned.level)
            let radiusSq = radius * radius
            let px = player.position.x
            let py = player.position.y
            ensureClerkGrid()
            let cells = max(1, Int(ceil(radius / clerkGrid.cellSize)))
            weaponHitBuffer.removeAll(keepingCapacity: true)
            clerkGrid.forEachNearby(to: player.position, cellsRadius: cells) { index in
                let clerk = clerks[index]
                let dx = clerk.position.x - px
                let dy = clerk.position.y - py
                if dx * dx + dy * dy <= radiusSq {
                    weaponHitBuffer.append(clerk)
                }
            }
            for clerk in weaponHitBuffer where clerk.parent != nil {
                hitClerk(clerk, damage: dmg, from: player.position, session: session, knockbackStrength: 90)
            }

        case .receipts:
            let targets = nearestClerks(count: min(1 + owned.level / 2, 3))
            for target in targets {
                let proj = ProjectileNode(weapon: .receipts, damage: dmg, life: 1.0, pierce: 1)
                proj.position = player.position
                let dx = target.position.x - player.position.x
                let dy = target.position.y - player.position.y
                let dist = max(1, hypot(dx, dy))
                proj.velocity = CGVector(dx: dx / dist * 320, dy: dy / dist * 320)
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
            if session.reducedFX == false {
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
            }
            let radiusSq = radius * radius
            let px = player.position.x
            let py = player.position.y
            ensureClerkGrid()
            let cells = max(1, Int(ceil(radius / clerkGrid.cellSize)))
            weaponHitBuffer.removeAll(keepingCapacity: true)
            clerkGrid.forEachNearby(to: player.position, cellsRadius: cells) { index in
                let clerk = clerks[index]
                let dx = clerk.position.x - px
                let dy = clerk.position.y - py
                if dx * dx + dy * dy <= radiusSq {
                    weaponHitBuffer.append(clerk)
                }
            }
            for clerk in weaponHitBuffer where clerk.parent != nil {
                hitClerk(clerk, damage: dmg, from: player.position, session: session, knockbackStrength: 280)
            }
        }
    }

    private func ensureClerkGrid() {
        if clerkGrid.buckets.isEmpty, !clerks.isEmpty {
            clerkGrid.rebuild(count: clerks.count) { clerks[$0].position }
        }
    }

    private func playWeaponFireSFX(_ kind: WeaponKind) {
        switch kind {
        // Aura ticks very often while overlapping clerks — keep it quiet / occasional.
        case .priceTags:
            if hitFeedbackCooldown <= 0 {
                AudioManager.shared.playSFX(.aura, volume: 0.22)
            }
        case .receipts: AudioManager.shared.playSFX(.receipt, volume: 0.4)
        case .barcodeLaser: AudioManager.shared.playSFX(.laser, volume: 0.35)
        case .shoppingBag: AudioManager.shared.playSFX(.bag, volume: 0.45)
        }
    }

    private func updateProjectiles(dt: TimeInterval) {
        guard let session else {
            projectiles.forEach { $0.removeFromParent() }
            projectiles.removeAll()
            return
        }
        let hitRadiusSq: CGFloat = 20 * 20
        var writeIndex = 0
        for proj in projectiles {
            proj.life -= dt
            if proj.life <= 0 || proj.pierceLeft <= 0 {
                proj.removeFromParent()
                continue
            }
            if proj.weapon == .receipts {
                proj.position.x += proj.velocity.dx * CGFloat(dt)
                proj.position.y += proj.velocity.dy * CGFloat(dt)
                let px = proj.position.x
                let py = proj.position.y
                ensureClerkGrid()
                var hit = false
                clerkGrid.forEachNearby(to: proj.position, cellsRadius: 1) { index in
                    guard !hit, index < clerks.count else { return }
                    let clerk = clerks[index]
                    let dx = clerk.position.x - px
                    let dy = clerk.position.y - py
                    if dx * dx + dy * dy < hitRadiusSq {
                        hitClerk(clerk, damage: proj.damage, from: proj.position, session: session)
                        proj.pierceLeft -= 1
                        hit = true
                    }
                }
            }
            if proj.pierceLeft > 0 && proj.life > 0 && proj.parent != nil {
                projectiles[writeIndex] = proj
                writeIndex += 1
            } else {
                proj.removeFromParent()
            }
        }
        if writeIndex < projectiles.count {
            projectiles.removeLast(projectiles.count - writeIndex)
        }
    }

    private func updateCoupons(dt: TimeInterval, session: GameSession) {
        couponLureScanAccum += dt
        let scanLure = couponLureScanAccum >= 0.25
        if scanLure { couponLureScanAccum = 0 }

        var keep: [CouponNode] = []
        for coupon in coupons {
            coupon.life -= dt
            if coupon.life <= 0 {
                coupon.removeFromParent()
            } else {
                if scanLure {
                    let lureRadiusSq = coupon.lureRadius * coupon.lureRadius
                    for clerk in clerks where clerk.lureTarget == nil {
                        let dx = clerk.position.x - coupon.position.x
                        let dy = clerk.position.y - coupon.position.y
                        if dx * dx + dy * dy <= lureRadiusSq {
                            clerk.lureTarget = coupon.position
                            clerk.lureTimeRemaining = min(3.0, coupon.life)
                        }
                    }
                }
                keep.append(coupon)
            }
        }
        coupons = keep
    }

    private func updateXPOrbs(dt: TimeInterval, session: GameSession) {
        let magnetRange: CGFloat = 70 + CGFloat(session.playerLevel) * 4
        let magnetRangeSq = magnetRange * magnetRange
        var keep: [XPOrbNode] = []
        for orb in xpOrbs {
            orb.life -= dt
            if orb.life <= 0 {
                orb.removeFromParent()
                continue
            }
            // Fade out in the last second so despawn is readable.
            if orb.life < 1.0 {
                orb.alpha = CGFloat(orb.life)
            }

            let dx = player.position.x - orb.position.x
            let dy = player.position.y - orb.position.y
            let distSq = dx * dx + dy * dy
            if distSq < 22 * 22 {
                gainXP(orb.amount, session: session)
                if hitFeedbackCooldown <= 0 {
                    AudioManager.shared.playSFX(.xp)
                    hitFeedbackCooldown = 0.05
                }
                orb.removeFromParent()
            } else if distSq < magnetRangeSq {
                let dist = sqrt(distSq)
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
        let distSq = max(1, dx * dx + dy * dy)
        let dist = sqrt(distSq)
        let kb = CGVector(dx: dx / dist * knockbackStrength, dy: dy / dist * knockbackStrength)
        // Cheap flash (no SKAction) — AoE used to spawn dozens of colorize actions per tick.
        let allowFlash = !session.reducedFX && clerks.count < 50
        clerk.applyDamage(damage, knockback: kb, flash: allowFlash)

        // One shared feedback window for SFX / haptics (aura/bag can hit 20+ clerks).
        if hitFeedbackCooldown <= 0 {
            AudioManager.shared.playSFX(.hit, volume: 0.5)
            Haptics.hit()
            hitFeedbackCooldown = session.reducedFX ? 0.12 : 0.07
        }

        if clerk.hp <= 0 {
            defeatClerk(clerk, session: session)
        }
    }

    private func defeatClerk(_ clerk: ClerkNode, session: GameSession) {
        guard let idx = clerks.firstIndex(where: { $0 === clerk }) else { return }
        let last = clerks.count - 1
        if idx < last { clerks[idx] = clerks[last] }
        clerks.removeLast()
        clerkGrid.clear()  // invalidate — removal changes indices, ensureClerkGrid rebuilds on next use
        refreshClerkNameTagsIfNeeded()
        if defeatSFXCooldown <= 0 {
            AudioManager.shared.playSFX(.defeat)
            defeatSFXCooldown = 0.09
        }

        let orb = XPOrbNode(amount: clerk.clerkType.xpReward)
        orb.position = clerk.position
        entityNode.addChild(orb)
        xpOrbs.append(orb)

        clerk.removeAllActions()
        clerk.colorBlendFactor = 0
        clerk.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.12),
                SKAction.scale(to: 0.3, duration: 0.12)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func spawnLevelUpFlash() {
        guard session?.reducedFX != true else { return }
        let flash = SKShapeNode(circleOfRadius: 40)
        flash.fillColor = SKColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 0.35)
        flash.strokeColor = SKColor(red: 0.5, green: 1.0, blue: 1.0, alpha: 0.8)
        flash.lineWidth = 2
        flash.position = player.position
        flash.zPosition = 45
        entityNode.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.2, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
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
            spawnLevelUpFlash()
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
        guard count > 0, !clerks.isEmpty else { return [] }
        let px = player.position.x
        let py = player.position.y
        if clerks.count <= count {
            return clerks.sorted {
                let d0 = ($0.position.x - px) * ($0.position.x - px) + ($0.position.y - py) * ($0.position.y - py)
                let d1 = ($1.position.x - px) * ($1.position.x - px) + ($1.position.y - py) * ($1.position.y - py)
                return d0 < d1
            }
        }

        var best: [(ClerkNode, CGFloat)] = []
        best.reserveCapacity(count)
        for clerk in clerks {
            let dx = clerk.position.x - px
            let dy = clerk.position.y - py
            let distSq = dx * dx + dy * dy
            if best.count < count {
                best.append((clerk, distSq))
                if best.count == count {
                    best.sort { $0.1 < $1.1 }
                }
            } else if distSq < best[count - 1].1 {
                best[count - 1] = (clerk, distSq)
                best.sort { $0.1 < $1.1 }
            }
        }
        return best.map(\.0)
    }

    private func updateCamera(dt: TimeInterval) {
        let target = player.position
        let blend: CGFloat = 0.12
        cameraNode.position.x += (target.x - cameraNode.position.x) * blend
        cameraNode.position.y += (target.y - cameraNode.position.y) * blend

        if shakeTime > 0, session?.reducedFX != true {
            shakeTime -= dt
            cameraNode.position.x += CGFloat.random(in: -3...3)
            cameraNode.position.y += CGFloat.random(in: -3...3)
        } else if shakeTime > 0 {
            shakeTime = 0
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
        let radiusSq = radius * radius
        if shelfRects.count <= 6 {
            for rect in shelfRects {
                resolveShelfRect(rect, radius: radius, radiusSq: radiusSq, previous: previous, into: &p)
            }
        } else {
            var resolved = p
            shelfGrid.forEachNearby(to: p, cellsRadius: 1) { index in
                resolveShelfRect(
                    shelfRects[index],
                    radius: radius,
                    radiusSq: radiusSq,
                    previous: previous,
                    into: &resolved
                )
            }
            p = resolved
        }
        node.position = p
        clampToArena(node)
    }

    private func resolveShelfRect(
        _ rect: CGRect,
        radius: CGFloat,
        radiusSq: CGFloat,
        previous: CGPoint,
        into p: inout CGPoint
    ) {
        let nearestX = min(max(p.x, rect.minX), rect.maxX)
        let nearestY = min(max(p.y, rect.minY), rect.maxY)
        let dx = p.x - nearestX
        let dy = p.y - nearestY
        let distSq = dx * dx + dy * dy
        if distSq < radiusSq {
            if distSq < 0.001 {
                p = previous
            } else {
                let dist = sqrt(distSq)
                let push = (radius - dist) / dist
                p.x += dx * push
                p.y += dy * push
            }
        }
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
}
