// This source file is part of the https://github.com/ColdGrub1384/Pisth open source project
//
// Copyright (c) 2017 - 2018 Adrian Labbé
// Licensed under Apache License v2.0
//
// See https://raw.githubusercontent.com/ColdGrub1384/Pisth/master/LICENSE for license information

import UIKit
import Pisth_Shared

/// The View controller for commiting files.
class SnippetsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UISearchBarDelegate, Storyboard {
    
    /// The table view displaying files.
    @IBOutlet weak var tableView: UITableView!
    
    /// The search bar for searching for snippets.
    @IBOutlet weak var searchBar: UISearchBar!
    
    private var connection_: RemoteConnection?
    
    /// The connection where snippets are from.
    var connection: RemoteConnection {
        if let connection = connection_ ?? connectionManager?.connection {
            return connection
        } else {
            fatalError("`connection` or `connectionManager` should be defined but both are undefined")
        }
    }
    
    /// The directory where the commands are ran.
    var directory: String?
    
    /// The connection manager where run snippets.
    var connectionManager: ConnectionManager?
    
    /// Snippets for the current connection.
    var snippets: [Snippet] {
        
        var text: String? {
            if Thread.current.isMainThread {
                return searchBar.text
            } else {
                var value: String?
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {
                    value = self.searchBar.text
                    semaphore.signal()
                }
                semaphore.wait()
                return value
            }
        }
        
        if searchBar.text == nil || searchBar.text?.isEmpty == true {
            return snippets_
        } else {
            return fetchedSnippets
        }
    }
    
    /// The view where the terminal will be presented.
    var fromView: UIView!
    
    /// Dismisses this View controller.
    @IBAction func dismissViewController(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    private var fetchedSnippets = [Snippet]()
    
    private var snippets_: [Snippet] {
        var snippets_ = [Snippet]()
        
        for snippet in allSnippets {
            if snippet.connection == "\(connection.username)@\(connection.host)" {
                snippets_.append(snippet)
            }
        }
        
        return snippets_
    }
    
    private var allSnippets: [Snippet] {
        get {
            if let data = UserKeys.snippets.dataValue, let snippets = try? JSONDecoder().decode([Snippet].self, from: data) {
                return snippets
            } else {
                return []
            }
        }
        
        set {
            do {
                UserKeys.snippets.dataValue = try JSONEncoder().encode(newValue)
            } catch {
                NSLog("%@", error.localizedDescription)
            }
        }
    }
    
    /// Enters in edit mode.
    @IBAction func editTableView(_ sender: UIButton) {
        
        if sender.tag == 0 {
            sender.setTitle(Localizable.SnippetsViewController.done, for: .normal)
            sender.tag = 1
        } else {
            sender.setTitle(Localizable.SnippetsViewController.edit, for: .normal)
            sender.tag = 0
        }
        
        tableView.setEditing((sender.tag != 0), animated: true)
    }
    
    
    /// Adds a snippet to the database.
    @IBAction func addSnippet(_ sender: Any) {
        
        if let alert = sender as? UIAlertController {
            present(alert, animated: true, completion: nil)
            return
        }
        
        let creationAlert = UIAlertController(title: Localizable.SnippetsViewController.createSnippet, message: Localizable.SnippetsViewController.createSnippetMessage, preferredStyle: .alert)
        creationAlert.addAction(UIAlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
        
        var titleTextField: UITextField?
        var codeTextField: UITextField?
        
        creationAlert.addAction(UIAlertAction(title: Localizable.SnippetsViewController.add, style: .default, handler: { (_) in
            guard let title = titleTextField?.text, let code = codeTextField?.text, !code.isEmpty else {
                
                creationAlert.message = Localizable.SnippetsViewController.emptyCode
                
                self.addSnippet(creationAlert)
                
                return
            }
            
            let snippet = Snippet(title: title, content: code, connection: "\(self.connection.username)@\(self.connection.host)")
            
            guard self.allSnippets.firstIndex(of: snippet) == nil else {
                
                creationAlert.message = Localizable.SnippetsViewController.alreadyExists
                
                self.addSnippet(creationAlert)
                
                return
            }
            
            self.allSnippets.append(snippet)
            self.tableView.insertRows(at: [IndexPath(row: self.snippets.count-1, section: 0)], with: .automatic)
        }))
        
        creationAlert.addTextField { (textField) in
            titleTextField = textField
            textField.placeholder = Localizable.SnippetsViewController.title
        }
        
        creationAlert.addTextField { (textField) in
            codeTextField = textField
            textField.placeholder = Localizable.SnippetsViewController.code
        }
        
        present(creationAlert, animated: true, completion: nil)
    }
    
    /// Makes a new View controller for managing snippets.
    ///
    /// - Parameters:
    ///     - connection: The connection where snippets are from.
    ///     - directory: The directory where run snippets.
    ///
    /// - Returns: A newly initialized View controller.
    static func makeViewController(connection: RemoteConnection, directory: String) -> SnippetsViewController {
        
        let vc = makeViewController()
        vc.connection_ = connection
        vc.directory = directory
        
        return vc
    }
    
    /// Makes a new View controller for managing snippets inside a terminal.
    ///
    /// - Parameters:
    ///     - connectionManager: The connectionn where run snippets.
    ///
    /// - Returns: A newly initialized View controller.
    static func makeViewController(connectionManager: ConnectionManager) -> SnippetsViewController {
        
        let vc = makeViewController()
        vc.connectionManager = connectionManager
        
        return vc
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            tableView.dragDelegate = self
            tableView.dragInteractionEnabled = true
        }
    }
    
    // MARK: - Table view data source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snippets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        
        let title = snippets[indexPath.row].title
        let content = snippets[indexPath.row].content
        
        if title.isEmpty {
            cell.textLabel?.text = content
        } else {
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = content
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: Localizable.UIMenuItem.delete, handler: { (_, indexPath) in
            if let index = self.allSnippets.firstIndex(of: self.snippets[indexPath.row]) {
                self.allSnippets.remove(at: index)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        })]
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return (searchBar.text == nil || searchBar.text?.isEmpty == true)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        let snippet = snippets[sourceIndexPath.row]
        
        guard let sourceIndex = allSnippets.firstIndex(of: snippet), let destinationIndex = allSnippets.firstIndex(of: snippet) else {
            return
        }
        
        allSnippets.remove(at: sourceIndex)
        allSnippets.insert(snippet, at: destinationIndex)
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        dismiss(animated: true) {
            if let manager = self.connectionManager {
                manager.runTask {
                    try? manager.session?.channel.write(self.snippets[indexPath.row].content+"\n")
                }
            } else {
                ContentViewController.shared.presentTerminal(inDirectory: self.directory, command: self.snippets[indexPath.row].content, fromView: self.fromView)
            }
        }
    }
    
    // MARK: - Table view drag delegate
    
    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        let item = UIDragItem(itemProvider: NSItemProvider(object: snippets[indexPath.row].content as NSItemProviderWriting))
        item.previewProvider = {
            guard let label = tableView.cellForRow(at: indexPath)?.textLabel else {
                return nil
            }
            return UIDragPreview(view: label)
        }
        
        return [item]
    }
    
    // MARK: - Search bar delegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        fetchedSnippets = []
        for snippet in snippets_ {
            if snippet.title.lowercased().contains(searchText.lowercased()) || snippet.content.lowercased().contains(searchText.lowercased()) {
                fetchedSnippets.append(snippet)
            }
        }
        self.tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { (_) in
            self.tableView.reloadData()
        })
    }
    
    // MARK: - Storyboard
    
    static var storyboard: UIStoryboard {
        return UIStoryboard(name: "Snippets", bundle: nil)
    }
}
