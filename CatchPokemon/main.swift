//
//  main.swift
//  CatchPokemon
//
//  Created by Matthew Ruston on 6/24/17.
//  Copyright © 2017 MattRuston. All rights reserved.
//

import Foundation


// MARK: Functions:

let pokemonPath = "http://pokeapi.co/api/v2/pokemon/"

struct PageResults {
    let pokemon: [[String: String]]?
    let nextPage: String?
}

//Fetches data for the specified pokemon number and writes it to the end
//of the pokemon.json file in my documents
func catchPokemon(pokemon: [String: String]) {
    guard let name = pokemon["name"], let path = pokemon["url"] else {
        print("Unable to parse pokemon: \(pokemon)")
        return
    }
    
    print("catching \(name)...")
    
    guard let url = URL(string: path) else {
        print("ERROR: Failed to create URL")
        return
    }
    
    //We want this call to be synchronous
    var semaphore = DispatchSemaphore(value: 0)
    
    URLSession.shared.dataTask(with: url) { (data, response, error) in
        defer { semaphore.signal() }
        
        if let error = error {
            print("ERROR: \(error)")
            return
        }
        
        guard let data = data else {
            print("ERROR: Data was nil")
            return
        }
        
        save(data: data, to: "pokemon.json")
    }.resume()
    
    semaphore.wait()
}

/// precondition: File must exist before this is called
func save(data: Data, to file: String) {
    if let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileUrl = documentDirectoryUrl.appendingPathComponent(file)
        
        do {
            let fileHandle = try FileHandle(forWritingTo: fileUrl)
            fileHandle.seekToEndOfFile()
            
            print("saving pokemon data to file...")
            fileHandle.write(data)
            fileHandle.seekToEndOfFile()
            
            if let stringData = ",\n".data(using: .utf8) {
                fileHandle.write(stringData)
            }
            
        } catch {
            print(error)
        }
    }
}

func getNextPage(path: String) -> PageResults {
    
    guard let url = URL(string: path) else {
        print("ERROR: Failed to create URL")
        return PageResults(pokemon: nil, nextPage: nil)
    }
    
    //Using semaphores to make this call synchronous
    let semaphore = DispatchSemaphore(value: 0)
    var pokemon: [[String: String]]?
    var nextPage: String?
    
    print("fetching page")
    URLSession.shared.dataTask(with: url) { (data, response, error) in
        defer { semaphore.signal() }
        
        if let error = error {
            print("ERROR: \(error)")
            return
        }
        
        guard let data = data else {
            print("ERROR: Data was nil")
            return
        }
        
        //Get the JSON into a dictionary
        var json: [String: Any]?
        do {
            json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print(error)
        }
        
        //Parse the data into our function variables
        if let results = json {
            pokemon = results["results"] as? [[String: String]]
            nextPage = results["next"] as? String
        }
    }.resume()
    
    semaphore.wait()
    return PageResults(pokemon: pokemon, nextPage: nextPage)
}


func catchAllPokemon() {
    var nextPage: String? = pokemonPath
    
    while let page = nextPage {
        let pageResults = getNextPage(path: page)
        nextPage = pageResults.nextPage
        if let pokemonList = pageResults.pokemon {
            for pokemon in pokemonList {
                catchPokemon(pokemon: pokemon)
                let seconds = arc4random_uniform(20) + 10
                print("Sleeping \(seconds)")
                sleep(seconds)
            }
        }
    }
}


//MARK: Main

catchAllPokemon()
