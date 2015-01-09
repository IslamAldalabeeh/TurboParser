// Copyright (c) 2012-2013 Andre Martins
// All Rights Reserved.
//
// This file is part of TurboParser 2.1.
//
// TurboParser 2.1 is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// TurboParser 2.1 is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with TurboParser 2.1.  If not, see <http://www.gnu.org/licenses/>.

#ifndef CONSTITUENCYDICTIONARY_H_
#define CONSTITUENCYDICTIONARY_H_

#include "Dictionary.h"
#include "TokenDictionary.h"
#include "SerializationUtils.h"
#include "ConstituencyReader.h"

class Pipe;

class ConstituencyDictionary : public Dictionary {
 public:
  ConstituencyDictionary() {}
  ConstituencyDictionary(Pipe* pipe) : pipe_(pipe) {}
  virtual ~ConstituencyDictionary() { Clear(); }

  virtual void Clear() {
    // Don't clear token_dictionary, since this class does not own it.
    constituent_alphabet_.clear();
  }

  virtual void Save(FILE *fs) {
    if (0 > constituent_alphabet_.Save(fs)) CHECK(false);
  }

  virtual void Load(FILE *fs) {
    if (0 > constituent_alphabet_.Load(fs)) CHECK(false);
    constituent_alphabet_.BuildNames();
  }

  void AllowGrowth() {
    token_dictionary_->AllowGrowth();
    constituent_alphabet_.AllowGrowth();
  }
  void StopGrowth() {
    token_dictionary_->StopGrowth();
    constituent_alphabet_.StopGrowth();
  }

  void CreateConstituentDictionary(ConstituencyReader *reader);

  const string &GetConstituentName(int id) const {
    return constituent_alphabet_.GetName(id);
  }

  TokenDictionary *GetTokenDictionary() const { return token_dictionary_; }
  void SetTokenDictionary(TokenDictionary *token_dictionary) {
    token_dictionary_ = token_dictionary;
  }

  const Alphabet &GetConstituentAlphabet() const {
    return constituent_alphabet_;
  }

 protected:
  Pipe *pipe_;
  TokenDictionary *token_dictionary_;
  Alphabet constituent_alphabet_;
};

#endif /* CONSTITUENCYDICTIONARY_H_ */
