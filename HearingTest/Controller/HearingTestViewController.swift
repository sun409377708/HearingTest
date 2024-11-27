import UIKit
import AVFoundation
import AVKit
import SnapKit
import MediaPlayer

class HearingTestViewController: UIViewController {
    
    // MARK: - Properties
    private let frequencies = [250, 500, 1000, 2000, 4000, 8000]
    private var currentFrequencyIndex = 0
    private let minVolume: Float = 0.0    // 起始音量改为 0 dB
    private let maxVolume: Float = 90.0   // 最大音量
    private let volumeStep: Float = 2.0    // 音量步进值
    private var currentVolume: Float = 0.0  // 初始值设为 0
    private var isPlaying = false
    private var volumeTimer: Timer?
    
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    
    private var hearingResults: [HearingResult] = []
    
    // MARK: - UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let volumeIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // 默认显示最小音量图标
        imageView.image = UIImage(systemName: "speaker.wave.1.fill")
        return imageView
    }()
    
    private let frequencyTitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Current Frequency", comment: "Label for current frequency")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let volumeTitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Current Volume", comment: "Label for current volume")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Hearing Test", comment: "Main title of hearing test screen")
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .darkText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Press when you hear a sound", comment: "Instruction for the hearing test")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let frequencyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let volumeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let heardButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Heard", comment: "Button title for heard sound"), for: .normal)
        button.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.layer.cornerRadius = 10
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Start Test", comment: "Button title for start test"), for: .normal)
        button.backgroundColor = .white
        button.setTitleColor(UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let volumeProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        progressView.trackTintColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupAudioSession()
        setupAudioEngine()
        updateLabels()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        volumeTimer?.invalidate()
        stopTone()
        audioEngine?.stop()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(volumeIconImageView)
        containerView.addSubview(frequencyTitleLabel)
        containerView.addSubview(frequencyLabel)
        containerView.addSubview(volumeTitleLabel)
        containerView.addSubview(volumeLabel)
        containerView.addSubview(heardButton)
        containerView.addSubview(playButton)
        containerView.addSubview(volumeProgressView)
        
        // SnapKit 约束
        containerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(320)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            make.bottom.equalTo(playButton.snp.bottom).offset(16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(containerView).offset(24)
            make.centerX.equalTo(containerView)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalTo(containerView)
        }
        
        volumeIconImageView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(32)
            make.centerX.equalTo(containerView)
            make.size.equalTo(100)
        }
        
        frequencyTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(volumeIconImageView.snp.bottom).offset(24)
            make.centerX.equalTo(containerView)
        }
        
        frequencyLabel.snp.makeConstraints { make in
            make.top.equalTo(frequencyTitleLabel.snp.bottom).offset(8)
            make.centerX.equalTo(containerView)
        }
        
        volumeTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(frequencyLabel.snp.bottom).offset(16)
            make.centerX.equalTo(containerView)
        }
        
        volumeLabel.snp.makeConstraints { make in
            make.top.equalTo(volumeTitleLabel.snp.bottom).offset(8)
            make.centerX.equalTo(containerView)
        }
        
        volumeProgressView.snp.makeConstraints { make in
            make.top.equalTo(volumeLabel.snp.bottom).offset(24)
            make.left.equalTo(containerView).offset(24)
            make.right.equalTo(containerView).offset(-24)
            make.height.equalTo(4)
        }
        
        heardButton.snp.makeConstraints { make in
            make.top.equalTo(volumeProgressView.snp.bottom).offset(40)
            make.left.equalTo(containerView).offset(24)
            make.right.equalTo(containerView).offset(-24)
            make.height.equalTo(44)
        }
        
        playButton.snp.makeConstraints { make in
            make.top.equalTo(heardButton.snp.bottom).offset(16)
            make.left.equalTo(containerView).offset(24)
            make.right.equalTo(containerView).offset(-24)
            make.height.equalTo(44)
        }
        
        heardButton.addTarget(self, action: #selector(heardButtonTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        
        // 监听系统音量变化
        setupVolumeObserver()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 设置系统音量为中间值 (0.5)
            let audioSession = AVAudioSession.sharedInstance()
            let volumeView = MPVolumeView()
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    slider.value = 0.5  // 设置为中间值
                }
            }
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        tonePlayer = AVAudioPlayerNode()
        
        guard let audioEngine = audioEngine,
              let tonePlayer = tonePlayer else { return }
        
        audioEngine.attach(tonePlayer)
        
        let mainMixer = audioEngine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        audioEngine.connect(tonePlayer, to: mainMixer, format: format)
        
        do {
            try audioEngine.start()
        } catch {
            showAlert(title: NSLocalizedString("Error", comment: "Alert title for error"), message: NSLocalizedString("Audio engine failed to start", comment: "Alert message for audio engine error"))
        }
    }
    
    // MARK: - Actions
    @objc private func heardButtonTapped() {
        // 记录当前频率的听力阈值
        let result = HearingResult(frequency: frequencies[currentFrequencyIndex], 
                                 threshold: currentVolume)
        hearingResults.append(result)
        
        if currentFrequencyIndex < frequencies.count - 1 {
            currentFrequencyIndex += 1
            currentVolume = minVolume  // 确保切换频率时重置为最小音量
            updateLabels()
            volumeProgressView.setProgress(0, animated: false)  // 重置进度条
            if isPlaying {
                stopTone()
                playTone()
            }
        } else {
            // 测试完成
            isPlaying = false
            updatePlayButtonTitle()
            showTestResults()
            stopTone()
        }
    }
    
    @objc private func playButtonTapped() {
        isPlaying.toggle()
        updatePlayButtonTitle()
        
        if isPlaying {
            currentVolume = minVolume
            updateLabels()
            volumeProgressView.setProgress(0, animated: false)
            playTone()
            startVolumeTimer()
            startIconAnimation()
        } else {
            stopTone()
            volumeTimer?.invalidate()
            stopIconAnimation()
        }
    }
    
    @objc private func historyButtonTapped() {
        let historyVC = HearingHistoryViewController()
        historyVC.modalPresentationStyle = .fullScreen
        present(historyVC, animated: true)
    }
    
    // MARK: - Helper Methods
    private func startVolumeTimer() {
        volumeTimer?.invalidate()
        currentVolume = minVolume  // 从 0 分贝开始
        
        volumeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            // 时间间隔改为 0.5 秒
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            
            if self.currentVolume < self.maxVolume {
                self.currentVolume += self.volumeStep  // 每次增加 2 分贝
                print("Current volume: \(self.currentVolume) dB")  // 添加日志
                self.updateLabels()
                self.updateToneVolume()
            } else {
                timer.invalidate()
                self.isPlaying = false
                self.updatePlayButtonTitle()
                self.showAlert(title: NSLocalizedString("Hint", comment: "Alert title for hint"), message: NSLocalizedString("Maximum volume reached, please switch to the next frequency", comment: "Alert message for maximum volume reached"))
            }
        }
    }
    
    private func updateToneVolume() {
        stopTone()
        playTone()
    }
    
    private func playTone() {
        guard let tonePlayer = tonePlayer else { return }
        
        let frequency = Float(frequencies[currentFrequencyIndex])
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        
        let phase = Float(2.0 * Double.pi)
        
        for frame in 0..<Int(frameCount) {
            let value = sin(phase * frequency * Float(frame) / Float(sampleRate))
            
            // 修改音量计算公式
            let dbValue = currentVolume  // dB值
            // 将分贝转换为线性振幅
            let amplitude = pow(10.0, (dbValue - 100.0) / 20.0)
            
            buffer.floatChannelData?[0][frame] = value * amplitude
        }
        
        buffer.frameLength = frameCount
        
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        tonePlayer.play()
    }
    
    private func stopTone() {
        tonePlayer?.stop()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert action title for OK"), style: .default))
        present(alert, animated: true)
    }
    
    private func updateLabels() {
        frequencyLabel.text = "\(frequencies[currentFrequencyIndex]) Hz"
        volumeLabel.text = String(format: "%.1f dB", currentVolume)
        
        // 更新进度条
        let progress = Float(currentVolume - minVolume) / Float(maxVolume - minVolume)
        volumeProgressView.setProgress(progress, animated: true)
    }
    
    private func updatePlayButtonTitle() {
        playButton.setTitle(isPlaying ? NSLocalizedString("Pause Test", comment: "Button title for pause test") : NSLocalizedString("Start Test", comment: "Button title for start test"), for: .normal)
    }
    
    private func showTestResults() {
        // 计算平均听力损失
        let averageThreshold = hearingResults.map { $0.threshold }.reduce(0, +) / Float(hearingResults.count)
        let severityLevel = HearingResult(frequency: 0, threshold: averageThreshold).getSeverityLevel()
        
        // 保存测试数据
        let defaults = UserDefaults.standard
        let testData: [String: Any] = [
            "date": Date(),
            "results": hearingResults.map { ["frequency": $0.frequency, "threshold": $0.threshold] },
            "averageThreshold": averageThreshold,
            "severity": severityLevel.rawValue
        ]
        
        // 获取现有历史记录
        var history = defaults.array(forKey: "HearingTestHistory") as? [[String: Any]] ?? []
        history.append(testData)
        
        // 只保留最近的10次记录
        if history.count > 10 {
            history.removeFirst(history.count - 10)
        }
        
        defaults.set(history, forKey: "HearingTestHistory")
        defaults.synchronize()
        
        print("Saved test results: \(testData)")  // 添加日志
        print("Current history count: \(history.count)")  // 添加日志
        
        // 展示结果页面
        let resultVC = HearingResultViewController()
        resultVC.modalPresentationStyle = .fullScreen
        resultVC.setResults(hearingResults)
        present(resultVC, animated: true)
    }
    
    private func resetTest() {
        currentFrequencyIndex = 0
        currentVolume = minVolume
        hearingResults.removeAll()
        updateLabels()
        volumeProgressView.setProgress(0, animated: false)
        isPlaying = false
        updatePlayButtonTitle()
        stopIconAnimation()
    }
    
    // MARK: - Volume Observer
    private func setupVolumeObserver() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(true)
            // 监听音量变化
            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(handleVolumeChange),
                                                 name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
                                                 object: nil)
        } catch {
            print("Error setting up volume observer: \(error)")
        }
    }
    
    @objc private func handleVolumeChange(_ notification: Notification) {
        // 移除强制设置音量的代码，让��户可以自由调节
    }
    
    // MARK: - Animation Methods
    private func startIconAnimation() {
        // 停止之前的动画
        volumeIconImageView.layer.removeAllAnimations()
        
        // 定义音量图标数组
        let volumeIcons = [
            UIImage(systemName: "speaker.wave.1.fill"),
            UIImage(systemName: "speaker.wave.2.fill"),
            UIImage(systemName: "speaker.wave.3.fill")
        ].compactMap { $0 }
        
        // 创建动画
        var images: [UIImage] = []
        // 添加正向序列
        images.append(contentsOf: volumeIcons)
        // 添加反向序列（不包括最后一个，避免重复）
        images.append(contentsOf: volumeIcons.dropLast().reversed())
        
        // 设置动画
        volumeIconImageView.animationImages = images
        volumeIconImageView.animationDuration = 1.5  // 动画周期
        volumeIconImageView.animationRepeatCount = 0 // 无限循环
        
        // 开始动画
        volumeIconImageView.startAnimating()
    }
    
    private func stopIconAnimation() {
        // 停止动画
        volumeIconImageView.stopAnimating()
        volumeIconImageView.animationImages = nil
        // 重置为初始图标
        volumeIconImageView.image = UIImage(systemName: "speaker.wave.1.fill")
    }
    
    // MARK: - Navigation Bar
    private func setupNavigationBar() {
        // 创建历史按钮
        let historyButton = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            style: .plain,
            target: self,
            action: #selector(historyButtonTapped)
        )
        historyButton.tintColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        
        // 设置为导航栏右侧按钮
        navigationItem.rightBarButtonItem = historyButton
    }
} 
