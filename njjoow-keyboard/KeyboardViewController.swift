import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    private var automata = HangulAutomata()
    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUI()
    }
    
    private func setupSwiftUI() {
        let keyboardView = KeyboardView(
            onKeyTap: { [weak self] jamo in
                self?.handleKeyTap(jamo)
            },
            onDelete: { [weak self] in
                self?.handleDelete()
            },
            onSpace: { [weak self] in
                self?.handleSpace()
            },
            onEnter: { [weak self] in
                self?.handleEnter()
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )
        
        let hostingController = UIHostingController(rootView: keyboardView)
        self.hostingController = hostingController
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Remove background color for a cleaner look
        hostingController.view.backgroundColor = .clear
    }
    
    private func handleKeyTap(_ jamo: String) {
        let (text, deleteCount) = automata.insert(jamo)
        
        for _ in 0..<deleteCount {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(text)
    }
    
    private func handleDelete() {
        let (text, deleteCount) = automata.delete()
        
        if deleteCount > 0 {
            for _ in 0..<deleteCount {
                textDocumentProxy.deleteBackward()
            }
            if !text.isEmpty {
                textDocumentProxy.insertText(text)
            }
        } else {
            // Nothing in automata, perform standard backspace
            textDocumentProxy.deleteBackward()
        }
    }
    
    private func handleSpace() {
        // Reset automata and insert space
        // automata = HangulAutomata() // Optional: preserve state? Usually space clears composition.
        // Let's reset for now.
        let (_, _) = automata.insert(" ") // This won't work perfectly since automata only handles jamo
        // Manual handle:
        textDocumentProxy.insertText(" ")
        // Reset automata state
        automata = HangulAutomata()
    }
    
    private func handleEnter() {
        textDocumentProxy.insertText("\n")
        automata = HangulAutomata()
    }
}
