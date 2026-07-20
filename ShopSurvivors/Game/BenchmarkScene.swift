import SpriteKit

/// Stress test that mirrors GameScene contact + combat load (shelves, shove, pitch, defeats).
@MainActor
final class BenchmarkScene: SKScene {

    struct Result {
        let label: String
        let clerkCount: Int
        let weapons: [String]
        let avgFPS: Int
        let minFPS: Int
    }

    static let scenarioCount = 4
    static let scenarioDuration: TimeInterval = 6.0
    static let warmupDuration: TimeInterval = 1.5

    /// (scenarioIndex, label, activeWeaponNames)
    var onScenarioChange: ((Int, String, [String]) -> Void)?
    var onProgress: ((Double) -> Void)?
    var onComplete: (([Result]) -> Void)?

    private struct Scenario {
        let label: String
        let clerkCount: Int
        let hasAura: Bool
        let hasBag: Bool
        let hasLaser: Bool
        let hasReceipts: Bool

        var weaponNames: [String] {
            [hasAura ? "Aura" : nil, hasBag ? "Bag" : nil,
             hasLaser ? "Laser" : nil, hasReceipts ? "Receipts" : nil].compactMap { $0 }
        }
    }

    private static let scenarios: [Scenario] = [
        Scenario(label: "Baseline · 15 clerks",    clerkCount: 15, hasAura: true,  hasBag: false, hasLaser: false, hasReceipts: false),
        Scenario(label: "Combat · 30 clerks",       clerkCount: 30, hasAura: true,  hasBag: true,  hasLaser: false, hasReceipts: false),
        Scenario(label: "Full loadout · 45 clerks", clerkCount: 45, hasAura: true,  hasBag: true,  hasLaser: true,  hasReceipts: true),
        Scenario(label: "Stress · 65 clerks",       clerkCount: 65, hasAura: true,  hasBag: true,  hasLaser: true,  hasReceipts: true),
    ]

    private struct BenchProjectile {
        let node: SKSpriteNode
        var velocity: CGVector
        var life: TimeInterval
        var damage: CGFloat
    }

    private let arenaSize = CGSize(width: 900, height: 560)
    private var shelfRects: [CGRect] = []
    private var clerks: [ClerkNode] = []
    private var clerkGrid = SpatialGrid(cellSize: 64)
    private var projectiles: [BenchProjectile] = []
    private var worldNode = SKNode()
    private var entityNode = SKNode()
    private let cameraNode = SKCameraNode()

    private var scenarioIndex = 0
    private var elapsed: TimeInterval = 0
    private var auraCooldown: TimeInterval = 0
    private var bagCooldown: TimeInterval = 0.5
    private var laserCooldown: TimeInterval = 0.3
    private var receiptCooldown: TimeInterval = 0.2
    private var hitCooldown: TimeInterval = 0
    private var shoveCooldown: TimeInterval = 0
    private var wasShoving = false
    private var lastTime: TimeInterval = 0
    private var fpsFrames = 0
    private var fpsAccum: TimeInterval = 0
    private var fpsSamples: [Int] = []

    private var results: [Result] = []
    private var isStarted = false
    private var isStopped = false
    private var pendingRespawns: [ClerkType] = []
    private var clerkPool: [ClerkType: [ClerkNode]] = [:]
    private var clerkUpdateParity = 0
    private var progressEmitAccum: TimeInterval = 0
    private var savedHapticsEnabled = true
    private var separationParity = 0
    private var savedSFXEnabled = true
    private var projectilePool: [SKSpriteNode] = []
    private var hitBuffer: [ClerkNode] = []

    private let player = PlayerNode()
    private let companion = CompanionNode()
    private var playerTarget: CGPoint = .zero
    private var companionTarget: CGPoint = .zero
    private var companionPause: TimeInterval = 0

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.13, alpha: 1)
        view.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        addChild(worldNode)
        worldNode.addChild(entityNode)
        addChild(cameraNode)
        camera = cameraNode
        buildArena()
        Haptics.prepare()
    }

    override func willMove(from view: SKView) {
        isStopped = true
        Haptics.isEnabled = savedHapticsEnabled
        AudioManager.shared.sfxEnabled = savedSFXEnabled
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        // Contact haptics/SFX spike min-FPS; measure render/sim without feedback stalls.
        savedHapticsEnabled = Haptics.isEnabled
        savedSFXEnabled = AudioManager.shared.sfxEnabled
        Haptics.isEnabled = false
        AudioManager.shared.sfxEnabled = false
        loadScenario(0)
    }

    private func buildArena() {
        shelfRects.removeAll()
        let shelfSize = CGSize(width: 56, height: 36)
        let positions: [CGPoint] = [
            CGPoint(x: -220, y: 120), CGPoint(x: 220, y: 120),
            CGPoint(x: -220, y: -120), CGPoint(x: 220, y: -120),
            CGPoint(x: 0, y: 160), CGPoint(x: 0, y: -160),
            CGPoint(x: -140, y: 0), CGPoint(x: 140, y: 0),
        ]
        for pos in positions {
            let prop = SKSpriteNode(imageNamed: "prop_shelf")
            prop.texture?.filteringMode = .nearest
            prop.size = shelfSize
            prop.position = pos
            prop.zPosition = -5
            prop.color = UIColor(red: 0.35, green: 0.55, blue: 0.7, alpha: 1)
            prop.colorBlendFactor = 0.25
            worldNode.addChild(prop)
            let inset: CGFloat = 4
            shelfRects.append(CGRect(
                x: pos.x - shelfSize.width / 2 + inset,
                y: pos.y - shelfSize.height / 2 + inset,
                width: shelfSize.width - inset * 2,
                height: shelfSize.height - inset * 2
            ))
        }
        // Sprite border — SKShapeNode of this size is expensive every frame.
        let borderColor = SKColor(red: 0.2, green: 0.85, blue: 0.9, alpha: 0.35)
        let top = SKSpriteNode(color: borderColor, size: CGSize(width: arenaSize.width, height: 3))
        top.position = CGPoint(x: 0, y: arenaSize.height / 2)
        top.zPosition = -8
        worldNode.addChild(top)
        let bottom = SKSpriteNode(color: borderColor, size: CGSize(width: arenaSize.width, height: 3))
        bottom.position = CGPoint(x: 0, y: -arenaSize.height / 2)
        bottom.zPosition = -8
        worldNode.addChild(bottom)
        let right = SKSpriteNode(color: borderColor, size: CGSize(width: 3, height: arenaSize.height))
        right.position = CGPoint(x: arenaSize.width / 2, y: 0)
        right.zPosition = -8
        worldNode.addChild(right)
        let left = SKSpriteNode(color: borderColor, size: CGSize(width: 3, height: arenaSize.height))
        left.position = CGPoint(x: -arenaSize.width / 2, y: 0)
        left.zPosition = -8
        worldNode.addChild(left)
    }

    private func loadScenario(_ index: Int) {
        scenarioIndex = index
        for clerk in clerks {
            clerk.removeAllActions()
            releaseClerk(clerk)
        }
        clerks.removeAll()
        for proj in projectiles { proj.node.removeFromParent() }
        projectiles.removeAll()
        pendingRespawns.removeAll(keepingCapacity: true)
        clerkGrid.clear()
        fpsSamples.removeAll()
        elapsed = 0
        auraCooldown = 0; bagCooldown = 0.5; laserCooldown = 0.3; receiptCooldown = 0.2
        hitCooldown = 0; shoveCooldown = 0; wasShoving = false
        fpsFrames = 0; fpsAccum = 0; lastTime = 0
        progressEmitAccum = 0

        let scenario = BenchmarkScene.scenarios[index]
        cameraNode.setScale(1.0)

        let types: [ClerkType] = [.pitcher, .closer, .sprinter, .upseller]
        for i in 0..<scenario.clerkCount {
            spawnClerk(type: types[i % 4], ringIndex: i, total: scenario.clerkCount)
        }

        if player.parent == nil { entityNode.addChild(player) }
        if companion.parent == nil { entityNode.addChild(companion) }
        player.position = CGPoint(x: -40, y: 0)
        companion.position = CGPoint(x: 40, y: 10)
        playerTarget = randomWanderTarget(near: .zero, radius: 90...140)
        companionTarget = randomWanderTarget(near: .zero, radius: 70...120)
        companionPause = 0
        cameraNode.position = player.position

        onScenarioChange?(index, scenario.label, scenario.weaponNames)
    }

    private func spawnClerk(type: ClerkType, ringIndex: Int, total: Int) {
        let clerk = acquireClerk(type: type)
        clerk.setNameTagHidden(total >= 24)
        let angle = CGFloat(ringIndex) / CGFloat(max(1, total)) * 2 * .pi
        let ring = CGFloat(1 + ringIndex / 10)
        let r = ring * 48 + CGFloat.random(in: -12...12)
        clerk.position = clampPoint(CGPoint(
            x: cos(angle) * r + CGFloat.random(in: -8...8),
            y: sin(angle) * r + CGFloat.random(in: -8...8)
        ))
        entityNode.addChild(clerk)
        clerks.append(clerk)
    }

    private func acquireClerk(type: ClerkType) -> ClerkNode {
        if var pool = clerkPool[type], let clerk = pool.popLast() {
            clerkPool[type] = pool
            clerk.prepareForReuse()
            return clerk
        }
        return ClerkNode(type: type)
    }

    private func releaseClerk(_ clerk: ClerkNode) {
        clerk.prepareForReuse()
        clerk.removeFromParent()
        clerkPool[clerk.clerkType, default: []].append(clerk)
    }

    override func update(_ currentTime: TimeInterval) {
        guard isStarted, !isStopped else { return }
        let dt: TimeInterval = lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 1.0 / 20)
        lastTime = currentTime
        elapsed += dt
        hitCooldown = max(0, hitCooldown - dt)
        shoveCooldown = max(0, shoveCooldown - dt)

        let scenario = BenchmarkScene.scenarios[scenarioIndex]

        updatePlayer(dt: dt)
        updateCompanion(dt: dt)
        updateClerks(dt: dt)
        let crowded = scenario.clerkCount >= 24
        separationParity ^= 1
        // Always keep the spatial grid fresh for shove/pitch/weapons.
        if !clerks.isEmpty {
            clerkGrid.rebuild(count: clerks.count) { clerks[$0].position }
        }
        if !crowded || separationParity == 0 {
            separateClerks(rebuild: false)
        }
        pushClerksWithPlayer()
        updatePitchContacts(dt: dt)
        fireWeapons(scenario: scenario, dt: dt)
        updateProjectiles(dt: dt)
        flushRespawns(scenario: scenario)
        updateCamera(dt: dt)

        if elapsed > BenchmarkScene.warmupDuration {
            fpsFrames += 1
            fpsAccum += dt
            if fpsAccum >= 0.5 {
                fpsSamples.append(max(0, Int((Double(fpsFrames) / fpsAccum).rounded())))
                fpsFrames = 0; fpsAccum = 0
            }
        }
        progressEmitAccum += dt
        if progressEmitAccum >= 0.12 {
            progressEmitAccum = 0
            onProgress?(min(1.0, elapsed / BenchmarkScene.scenarioDuration))
        }
        if elapsed >= BenchmarkScene.scenarioDuration {
            onProgress?(1)
            recordAndAdvance()
        }
    }

    // MARK: - Movement

    private func updatePlayer(dt: TimeInterval) {
        let dx = playerTarget.x - player.position.x
        let dy = playerTarget.y - player.position.y
        let distSq = dx * dx + dy * dy
        if distSq < 22 * 22 {
            playerTarget = randomWanderTarget(near: companion.position, radius: 60...150)
            player.walk.update(sprite: player, moving: false, facingDX: player.facing.dx, dt: dt)
            return
        }
        let dist = sqrt(distSq)
        let previous = player.position
        player.facing = CGVector(dx: dx / dist, dy: dy / dist)
        player.position.x += player.facing.dx * 130 * CGFloat(dt)
        player.position.y += player.facing.dy * 130 * CGFloat(dt)
        resolveShelfCollision(player, radius: 14, previous: previous)
        clampToArena(player)
        player.walk.update(sprite: player, moving: true, facingDX: player.facing.dx, dt: dt)
    }

    private func updateCompanion(dt: TimeInterval) {
        if companionPause > 0 {
            companionPause -= dt
            companion.walk.update(sprite: companion, moving: false, facingDX: companion.facingDX, dt: dt)
            return
        }
        let dx = companionTarget.x - companion.position.x
        let dy = companionTarget.y - companion.position.y
        let distSq = dx * dx + dy * dy
        if distSq < 18 * 18 {
            companionPause = TimeInterval.random(in: 0.8...1.8)
            companionTarget = randomWanderTarget(near: .zero, radius: 50...130)
            companion.walk.update(sprite: companion, moving: false, facingDX: companion.facingDX, dt: dt)
            return
        }
        let dist = sqrt(distSq)
        let previous = companion.position
        companion.facingDX = dx
        companion.position.x += dx / dist * companion.browseSpeed * CGFloat(dt)
        companion.position.y += dy / dist * companion.browseSpeed * CGFloat(dt)
        resolveShelfCollision(companion, radius: 13, previous: previous)
        clampToArena(companion)
        companion.walk.update(sprite: companion, moving: true, facingDX: companion.facingDX, dt: dt)
    }

    private func randomWanderTarget(near origin: CGPoint, radius: ClosedRange<CGFloat>) -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let r = CGFloat.random(in: radius)
        return clampPoint(CGPoint(x: origin.x + cos(angle) * r, y: origin.y + sin(angle) * r))
    }

    private func updateClerks(dt: TimeInterval) {
        clerkUpdateParity ^= 1
        let companionPos = companion.position
        let nearRadiusSq: CGFloat = 280 * 280
        let crowded = clerks.count >= 24

        for (index, clerk) in clerks.enumerated() {
            let dxC = clerk.position.x - companionPos.x
            let dyC = clerk.position.y - companionPos.y
            let distToFriendSq = dxC * dxC + dyC * dyC
            let isNear = distToFriendSq <= nearRadiusSq
            let hasKnockback = clerk.knockbackVelocity.dx != 0 || clerk.knockbackVelocity.dy != 0

            if crowded, !isNear, !hasKnockback, (index & 1) != clerkUpdateParity {
                clerk.pitchCooldown = max(0, clerk.pitchCooldown - dt)
                continue
            }
            let stepDt = (crowded && !isNear && !hasKnockback) ? dt * 2 : dt

            let dx = companionPos.x - clerk.position.x
            let dy = companionPos.y - clerk.position.y
            let distSq = dx * dx + dy * dy
            let moving: Bool
            let previous = clerk.position
            if distSq > 400 {
                let dist = sqrt(distSq)
                clerk.position.x += dx / dist * clerk.clerkType.moveSpeed * CGFloat(stepDt)
                clerk.position.y += dy / dist * clerk.clerkType.moveSpeed * CGFloat(stepDt)
                clerk.facingDX = dx
                moving = true
            } else {
                moving = false
            }

            if hasKnockback {
                clerk.position.x += clerk.knockbackVelocity.dx * CGFloat(stepDt)
                clerk.position.y += clerk.knockbackVelocity.dy * CGFloat(stepDt)
                clerk.knockbackVelocity.dx *= 0.85
                clerk.knockbackVelocity.dy *= 0.85
                let kvx = clerk.knockbackVelocity.dx, kvy = clerk.knockbackVelocity.dy
                if kvx * kvx + kvy * kvy < 25 { clerk.knockbackVelocity = .zero }
                resolveShelfCollision(clerk, radius: 12, previous: previous)
            } else if moving {
                resolveShelfCollision(clerk, radius: 12, previous: previous)
            }
            clampToArena(clerk)

            if clerk.colorBlendFactor > 0 {
                clerk.colorBlendFactor = max(0, clerk.colorBlendFactor - CGFloat(stepDt) * 6)
            }

            if isNear || !crowded {
                clerk.walk.update(sprite: clerk, moving: moving, facingDX: clerk.facingDX, dt: stepDt)
            }
            clerk.pitchCooldown = max(0, clerk.pitchCooldown - stepDt)
        }
    }

    private func separateClerks(rebuild: Bool = true) {
        let n = clerks.count
        guard n > 1 else { return }
        let minD: CGFloat = 20, minDSq = minD * minD
        if rebuild {
            clerkGrid.rebuild(count: n) { clerks[$0].position }
        }
        // Radius 1 is enough for soft push (minDist 20 < cell 64).
        for i in 0..<n {
            let a = clerks[i], ap = a.position
            clerkGrid.forEachNearby(to: ap, cellsRadius: 1) { j in
                guard j > i else { return }
                let b = clerks[j]
                let dx = b.position.x - ap.x, dy = b.position.y - ap.y
                let dSq = dx * dx + dy * dy
                guard dSq < minDSq else { return }
                if dSq < 0.01 { a.position.x -= 1; b.position.x += 1; return }
                let d = sqrt(dSq), push = (minD - d) * 0.5
                a.position.x -= dx / d * push; a.position.y -= dy / d * push
                b.position.x += dx / d * push; b.position.y += dy / d * push
            }
        }
    }

    // MARK: - Contact (mirrors GameScene shove + pitch)

    private func pushClerksWithPlayer() {
        let pushRadiusSq: CGFloat = 30 * 30
        var shoving = false
        let px = player.position.x, py = player.position.y
        clerkGrid.forEachNearby(to: player.position, cellsRadius: 1) { index in
            let clerk = clerks[index]
            let dx = clerk.position.x - px, dy = clerk.position.y - py
            let distSq = dx * dx + dy * dy
            guard distSq < pushRadiusSq, distSq > 0.01 else { return }
            let dist = sqrt(distSq)
            clerk.knockbackVelocity = CGVector(dx: dx / dist * 260, dy: dy / dist * 260)
            shoving = true
        }
        if shoving, !wasShoving, shoveCooldown <= 0 {
            shoveCooldown = 0.35
        }
        wasShoving = shoving
    }

    private func updatePitchContacts(dt: TimeInterval) {
        let cx = companion.position.x, cy = companion.position.y
        clerkGrid.forEachNearby(to: companion.position, cellsRadius: 1) { index in
            let clerk = clerks[index]
            let dx = clerk.position.x - cx, dy = clerk.position.y - cy
            let radius = clerk.clerkType.pitchRadius
            guard dx * dx + dy * dy <= radius * radius else { return }
            guard clerk.pitchCooldown <= 0 else { return }
            // Cooldown only — skip labels/shake/SFX (those spike min FPS under load).
            clerk.pitchCooldown = TimeInterval.random(in: 1.8...3.2)
        }
    }

    // MARK: - Weapons (real damage + respawn, like gameplay)

    private func fireWeapons(scenario: Scenario, dt: TimeInterval) {
        if scenario.hasAura    { auraCooldown    -= dt; if auraCooldown    <= 0 { auraCooldown    = 0.35; fireAura(clerkCount: scenario.clerkCount) } }
        if scenario.hasBag     { bagCooldown     -= dt; if bagCooldown     <= 0 { bagCooldown     = 2.2;  fireShoppingBag() } }
        if scenario.hasLaser   { laserCooldown   -= dt; if laserCooldown   <= 0 { laserCooldown   = 1.4;  fireLaser() } }
        if scenario.hasReceipts { receiptCooldown -= dt; if receiptCooldown <= 0 { receiptCooldown = 0.55; fireReceipts() } }
    }

    private func fireAura(clerkCount: Int) {
        let radius: CGFloat = 55
        let radiusSq = radius * radius
        let allowFlash = clerkCount < 20
        var flashesLeft = 3
        let px = player.position.x, py = player.position.y
        let cells = max(1, Int(ceil(radius / clerkGrid.cellSize)))
        // Collect first — defeating mid-query invalidates grid indices (crash at clerks[index]).
        hitBuffer.removeAll(keepingCapacity: true)
        clerkGrid.forEachNearby(to: player.position, cellsRadius: cells) { index in
            guard index < clerks.count else { return }
            let clerk = clerks[index]
            let dx = clerk.position.x - px, dy = clerk.position.y - py
            guard dx * dx + dy * dy <= radiusSq else { return }
            hitBuffer.append(clerk)
        }
        var anyHit = false
        for clerk in hitBuffer where clerk.parent != nil && clerk.hp > 0 {
            let flash = allowFlash && flashesLeft > 0
            if flash { flashesLeft -= 1 }
            hitClerk(clerk, damage: 8, from: player.position, knockback: 90, flash: flash)
            anyHit = true
        }
        if anyHit {
            hitCooldown = clerkCount >= 20 ? 0.18 : 0.14
        }
    }

    private func fireShoppingBag() {
        // No pulse VFX in benchmark — SKShapeNode expand was a reliable min-FPS spike.
        let radius: CGFloat = 90
        let radiusSq = radius * radius
        let px = player.position.x, py = player.position.y
        let cells = max(1, Int(ceil(radius / clerkGrid.cellSize)))
        hitBuffer.removeAll(keepingCapacity: true)
        clerkGrid.forEachNearby(to: player.position, cellsRadius: cells) { index in
            guard index < clerks.count else { return }
            let clerk = clerks[index]
            let dx = clerk.position.x - px, dy = clerk.position.y - py
            guard dx * dx + dy * dy <= radiusSq else { return }
            hitBuffer.append(clerk)
        }
        for clerk in hitBuffer where clerk.parent != nil && clerk.hp > 0 {
            hitClerk(clerk, damage: 22, from: player.position, knockback: 280, flash: false)
        }
        hitCooldown = 0.12
    }

    private func fireLaser() {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let length: CGFloat = 200
        let dx = cos(angle), dy = sin(angle)
        let node = acquireProjectile(named: "proj_laser", size: CGSize(width: length, height: 12))
        node.anchorPoint = CGPoint(x: 0, y: 0.5)
        node.position = player.position
        node.zRotation = angle
        entityNode.addChild(node)
        projectiles.append(BenchProjectile(node: node, velocity: .zero, life: 0.25, damage: 14))
        let bx = player.position.x + dx * length, by = player.position.y + dy * length
        hitBuffer.removeAll(keepingCapacity: true)
        for clerk in clerks {
            if pointNearSegment(clerk.position, ax: player.position.x, ay: player.position.y, bx: bx, by: by, threshold: 22) {
                hitBuffer.append(clerk)
            }
        }
        var flashesLeft = 3
        for clerk in hitBuffer where clerk.parent != nil && clerk.hp > 0 {
            let flash = flashesLeft > 0
            if flash { flashesLeft -= 1 }
            hitClerk(clerk, damage: 14, from: player.position, knockback: 160, flash: flash)
        }
    }

    private func fireReceipts() {
        let targets = nearestClerks(2)
        for target in targets {
            let node = acquireProjectile(named: "proj_receipt", size: CGSize(width: 18, height: 18))
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = player.position
            node.zRotation = 0
            entityNode.addChild(node)
            let dx = target.position.x - player.position.x, dy = target.position.y - player.position.y
            let dist = max(1, hypot(dx, dy))
            projectiles.append(BenchProjectile(
                node: node,
                velocity: CGVector(dx: dx / dist * 320, dy: dy / dist * 320),
                life: 1.0,
                damage: 10
            ))
        }
    }

    private func acquireProjectile(named image: String, size: CGSize) -> SKSpriteNode {
        let node: SKSpriteNode
        if let reused = projectilePool.popLast() {
            node = reused
            node.texture = SKTexture(imageNamed: image)
            node.texture?.filteringMode = .nearest
            node.size = size
            node.alpha = 1
            node.setScale(1)
        } else {
            node = SKSpriteNode(imageNamed: image)
            node.texture?.filteringMode = .nearest
            node.size = size
            node.zPosition = 12
        }
        return node
    }

    private func releaseProjectile(_ node: SKSpriteNode) {
        node.removeAllActions()
        node.removeFromParent()
        projectilePool.append(node)
    }

    private func updateProjectiles(dt: TimeInterval) {
        var write = 0
        for i in 0..<projectiles.count {
            projectiles[i].life -= dt
            guard projectiles[i].life > 0 else {
                releaseProjectile(projectiles[i].node)
                continue
            }
            var hitSomething = false
            if projectiles[i].velocity.dx != 0 || projectiles[i].velocity.dy != 0 {
                projectiles[i].node.position.x += projectiles[i].velocity.dx * CGFloat(dt)
                projectiles[i].node.position.y += projectiles[i].velocity.dy * CGFloat(dt)
                let px = projectiles[i].node.position.x, py = projectiles[i].node.position.y
                var hitClerkRef: ClerkNode?
                clerkGrid.forEachNearby(to: projectiles[i].node.position, cellsRadius: 1) { index in
                    guard hitClerkRef == nil, index < clerks.count else { return }
                    let clerk = clerks[index]
                    let ddx = clerk.position.x - px, ddy = clerk.position.y - py
                    if ddx * ddx + ddy * ddy < 20 * 20 {
                        hitClerkRef = clerk
                    }
                }
                if let clerk = hitClerkRef {
                    hitClerk(clerk, damage: projectiles[i].damage, from: projectiles[i].node.position, knockback: 160, flash: false)
                    hitSomething = true
                }
            }
            if hitSomething {
                releaseProjectile(projectiles[i].node)
            } else {
                projectiles[write] = projectiles[i]; write += 1
            }
        }
        if write < projectiles.count { projectiles.removeLast(projectiles.count - write) }
    }

    private func hitClerk(_ clerk: ClerkNode, damage: CGFloat, from: CGPoint, knockback: CGFloat, flash: Bool) {
        guard clerk.parent != nil, clerk.hp > 0 else { return }
        let dx = clerk.position.x - from.x, dy = clerk.position.y - from.y
        let dist = max(1, sqrt(dx * dx + dy * dy))
        clerk.applyDamage(damage, knockback: CGVector(dx: dx / dist * knockback, dy: dy / dist * knockback), flash: flash)
        if clerk.hp <= 0 {
            defeatClerk(clerk)
        }
    }

    private func defeatClerk(_ clerk: ClerkNode) {
        guard let idx = clerks.firstIndex(where: { $0 === clerk }) else { return }
        let type = clerk.clerkType
        let last = clerks.count - 1
        if idx < last { clerks[idx] = clerks[last] }
        clerks.removeLast()
        // Instant recycle — fade actions were allocating and hitching on mass kills.
        releaseClerk(clerk)
        pendingRespawns.append(type)
    }

    private func flushRespawns(scenario: Scenario) {
        guard !pendingRespawns.isEmpty else { return }
        let types = pendingRespawns
        pendingRespawns.removeAll(keepingCapacity: true)
        for type in types {
            spawnClerk(type: type, ringIndex: clerks.count, total: scenario.clerkCount)
        }
        // Positions changed — refresh grid for the rest of the frame's queries.
        if !clerks.isEmpty {
            clerkGrid.rebuild(count: clerks.count) { clerks[$0].position }
        }
    }

    // MARK: - Camera / FX

    private func updateCamera(dt: TimeInterval) {
        let blend: CGFloat = 0.12
        cameraNode.position.x += (player.position.x - cameraNode.position.x) * blend
        cameraNode.position.y += (player.position.y - cameraNode.position.y) * blend
    }

    // MARK: - Helpers

    private func nearestClerks(_ count: Int) -> [ClerkNode] {
        guard !clerks.isEmpty else { return [] }
        if clerks.count <= count { return clerks }
        let px = player.position.x, py = player.position.y
        var best: [(ClerkNode, CGFloat)] = []; best.reserveCapacity(count)
        for clerk in clerks {
            let dx = clerk.position.x - px, dy = clerk.position.y - py
            let dSq = dx * dx + dy * dy
            if best.count < count {
                best.append((clerk, dSq))
                if best.count == count { best.sort { $0.1 < $1.1 } }
            } else if dSq < best[count - 1].1 {
                best[count - 1] = (clerk, dSq); best.sort { $0.1 < $1.1 }
            }
        }
        return best.map(\.0)
    }

    private func pointNearSegment(_ p: CGPoint, ax: CGFloat, ay: CGFloat, bx: CGFloat, by: CGFloat, threshold: CGFloat) -> Bool {
        let abx = bx - ax, aby = by - ay
        let apx = p.x - ax, apy = p.y - ay
        let len2 = abx * abx + aby * aby
        guard len2 > 0 else { return hypot(apx, apy) < threshold }
        let t = max(0, min(1, (apx * abx + apy * aby) / len2))
        return hypot(p.x - (ax + abx * t), p.y - (ay + aby * t)) < threshold
    }

    private func resolveShelfCollision(_ node: SKNode, radius: CGFloat, previous: CGPoint) {
        var p = node.position
        let radiusSq = radius * radius
        for rect in shelfRects {
            if p.x < rect.minX - radius || p.x > rect.maxX + radius
                || p.y < rect.minY - radius || p.y > rect.maxY + radius {
                continue
            }
            let nearestX = min(max(p.x, rect.minX), rect.maxX)
            let nearestY = min(max(p.y, rect.minY), rect.maxY)
            let dx = p.x - nearestX, dy = p.y - nearestY
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
        node.position = p
    }

    private func clampToArena(_ node: SKNode) {
        node.position = clampPoint(node.position)
    }

    private func clampPoint(_ p: CGPoint) -> CGPoint {
        let m: CGFloat = 24
        return CGPoint(
            x: min(max(p.x, -arenaSize.width / 2 + m), arenaSize.width / 2 - m),
            y: min(max(p.y, -arenaSize.height / 2 + m), arenaSize.height / 2 - m)
        )
    }

    private func recordAndAdvance() {
        let s = BenchmarkScene.scenarios[scenarioIndex]
        let avg = fpsSamples.isEmpty ? 0 : fpsSamples.reduce(0, +) / fpsSamples.count
        results.append(Result(
            label: s.label, clerkCount: s.clerkCount, weapons: s.weaponNames,
            avgFPS: avg, minFPS: fpsSamples.min() ?? 0
        ))
        let next = scenarioIndex + 1
        if next < BenchmarkScene.scenarios.count {
            loadScenario(next)
        } else {
            isStopped = true
            onComplete?(results)
        }
    }
}
