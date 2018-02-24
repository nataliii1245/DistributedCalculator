//
//  ViewController.swift
//  DistributedCalculator
//
//  Created by Наталия Волкова on 23.02.2018.
//  Copyright © 2018 natalii. All rights reserved.
//

import Cocoa
import SwiftSocket

class ViewController: NSViewController {
    
    // MARK: - Outlets
    
    // Путь к файлу с IP-адресами
    @IBOutlet weak var listFilePathControl: NSPathControl!
    // Номер порта для соединения
    @IBOutlet weak var portNumberTextField: NSTextField!
    
    // IP-адрес сервера
    @IBOutlet weak var serverIPAddressTextField: NSTextField!
    // Кнопка "Запустить сервер"
    @IBOutlet weak var startServerButton: NSButton!
    // Кнопка "Остановить"
    @IBOutlet weak var stopServerButton: NSButton! {
        willSet {
            newValue.isEnabled = false
        }
    }
    
    // Путь к файлу с картой расчетов
    @IBOutlet weak var calculationMapFilePathControl: NSPathControl!
    // Лог
    @IBOutlet weak var logTextView: NSTextView! {
        willSet {
            newValue.isEditable = false
        }
    }
    
    // MARK: - Приватные свойства
    
    private var queue = DispatchQueue(label: "ru.nataliii.queue", qos: .utility, attributes: .concurrent)
    
    /// URL файла c IP - адресами
    private var addressListUrl: URL? {
        willSet {
            self.listFilePathControl.url = newValue
        }
    }
    /// URL файла c картой расчетов
    private var calculationMapUrl: URL? {
        willSet {
            self.calculationMapFilePathControl.url = newValue
        }
    }
    
    private var server: TCPServer?
    
}


// MARK: - Приватные вычисляемые свойства

private extension ViewController {
    /// Порт
    var port: Int32 {
        return self.portNumberTextField.intValue
    }
    
    /// IP сервера
    var serverIp: String {
        return self.serverIPAddressTextField.stringValue
    }
    
    /// Случайный IP из списка адресов серверов
    var randomIp: String? {
        guard let addressList = getListOfAddresses() else { return nil }
        
        let index = Int(arc4random_uniform(UInt32(addressList.count - 1)))
        return addressList[index]
    }
    
}


// MARK: - IBActions

extension ViewController {
    
    /// Нажата кнопка "Выбрать список"
    @IBAction func selectAddressListButtonClicked(sender: NSButton) {
        
        let dialog = NSOpenPanel()
        
        dialog.title = "Выберите .json файл"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["json"]
        
        if dialog.runModal() == .OK {
            guard let url = dialog.url else { return }
            self.addressListUrl = url
        }
    }
    
    /// Нажата кнопка "Запустить сервер"
    @IBAction func startServerButtonPressed(_ sender: NSButton) {
        let port = self.port
        let serverIp = self.serverIp
        
        self.queue.async {
            self.startServer(serverIp: serverIp, port: port)
        }
        
        sender.isEnabled = false
        self.stopServerButton.isEnabled = true
    }
    
    /// Нажата кнопка "Остановить сервер"
    @IBAction func stopServerButtonClicked(_ sender: NSButton) {
        self.server?.close()
        self.server = nil
        
        sender.isEnabled = false
        self.startServerButton.isEnabled = true
    }
    
    /// Нажата кнопка "Выбрать карту вычислений"
    @IBAction func selectCalculationMapButtonClicked(sender: NSButton) {
        
        let dialog = NSOpenPanel()
        
        dialog.title = "Выберите .json файл"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["json"]
        
        if dialog.runModal() == .OK {
            guard let url = dialog.url else { return }
            self.calculationMapUrl = url
        }
    }
    
    /// Отправить карту вычислений
    @IBAction func startCalculationButtonPressed(sender: NSButton) {
        
        let port = self.port
        
        guard let calculationMap = getCalculationMap() else { return }
        guard let randomIp = self.randomIp else { return }
        
        self.queue.async {
            self.startClient(clientIp: randomIp, port: port, calculationMap: calculationMap)
        }
    }

}


// MARK: - Приватные методы

extension ViewController {
    
    /// Лог
    func log(message: String) {
        DispatchQueue.main.async {
            self.logTextView.string += message + "\n"
            self.logTextView.scrollToEndOfDocument(self)
        }
    }
    
    /// Получить список IP - адресов из файла
    func getListOfAddresses() -> [String]? {
        guard let addressListUrl = self.addressListUrl, let data = try? Data(contentsOf: addressListUrl) else { return nil }
        
        let decoder = JSONDecoder()
        guard let addressList = try? decoder.decode([String].self, from: data) else { return nil }
        
        return addressList
    }
    
    /// Получить карту расчетов
    func getCalculationMap() -> CalculationMap? {
        guard let calculationMapUrl = self.calculationMapUrl, let data = try? Data(contentsOf: calculationMapUrl) else { return nil }
        
        let decoder = JSONDecoder()
        guard let calculationMap = try? decoder.decode(CalculationMap.self, from: data) else { return nil }
        
        return calculationMap
    }
    
    /// Выполнить операцию
    func performOperation(calculationMap: CalculationMap) {
        guard calculationMap.mathOperations.first?.action == "x" else { return }
        let _ = calculationMap.mathOperations.removeFirst()
        
        if calculationMap.currentNumber == 0 {
            calculationMap.currentNumber = 0
        } else {
            let result = 1.0 / calculationMap.currentNumber
            calculationMap.currentNumber = result
        }
        
    }
    
    /// Запустить режим клиента
    func startClient(clientIp: String, port: Int32, calculationMap: CalculationMap) {
        let client = TCPClient(address: clientIp, port: port)
        switch client.connect(timeout: 10) {
        case .success:
            defer { client.close() }
            
            log(message: "IP-адрес получателя: \(clientIp)")
            log(message: "Количество операций: \(calculationMap.mathOperations.count)")
            log(message: "Входящее число: \(calculationMap.currentNumber)")
            log(message: "Первая операция: \(calculationMap.mathOperations.first?.action ?? "") \(calculationMap.mathOperations.first?.operand ?? 0)")
            log(message: "")
            
            let data = calculationMap.data!
            switch client.send(data: data) {
            case .success:
                log(message: "Данные успешно отправлены: \(data)")
            case .failure(let error):
                log(message: "Ошибка при отправке данных получателю: \(error.localizedDescription)")
            }
        case .failure(let error):
            log(message: "Ошибка при подключении к получателю: \(error.localizedDescription)")
            
            guard let randomIp = self.randomIp else { return }
            self.queue.async {
                self.startClient(clientIp: randomIp, port: port, calculationMap: calculationMap)
            }
        }
        
        log(message: "")
    }
    
    /// Запустить сервер
    func startServer(serverIp: String, port: Int32) {
        self.server?.close()
        
        let server = TCPServer(address: serverIp, port: port)
        self.server = server
        
        switch server.listen() {
        case .success:
            while server.fd != nil {
                guard let client = server.accept() else {
                    log(message: "Ошибка при подключении клиента")
                    continue
                }
                defer { client.close() }
                
                log(message: "IP-адрес клиента: \(client.address)")
                
                guard let bytes = client.read(1024 * 10) else {
                    log(message: "Ошибка при чтении данных от клиента")
                    continue
                }
                
                let data = Data(bytes)
                guard let calculationMap = CalculationMap(data: data) else {
                    log(message: "Входящие данные имеют неверный формат")
                    continue
                }
                
                log(message: "Количество операций: \(calculationMap.mathOperations.count)")
                log(message: "Входящее число: \(calculationMap.currentNumber)")
                log(message: "Первая операция: \(calculationMap.mathOperations.first?.action ?? "") \(calculationMap.mathOperations.first?.operand ?? 0)")
                log(message: "")
                
                performOperation(calculationMap: calculationMap)
                
                if calculationMap.mathOperations.first?.action == "=" {
                    log(message: "Результат вычислений: \(calculationMap.currentNumber)")
                    log(message: "")
                } else {
                    guard let randomIp = self.randomIp else { continue }
                    
                    self.queue.async {
                        self.startClient(clientIp: randomIp, port: port, calculationMap: calculationMap)
                    }
                }
            }
        case .failure(let error):
            log(message: "Ошибка: \(error.localizedDescription)")
        }
    }
    
}
