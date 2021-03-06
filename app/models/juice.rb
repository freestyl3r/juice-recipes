class Juice
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include Elasticsearch::Persistence::Model

  settings analysis: {
    analyzer: {
      whitelist_ingredients: {
        type: 'custom',
        tokenizer: 'standard',
        filter: ['lowercase', 'singularize', 'keep_ingredients']
      }
    },
    filter: {
      singularize: {
        type: 'inflections',
        inflection: 'singularize'
      },
      keep_ingredients: {
        type: 'keep',
        keep_words_path: 'ingredients.txt'
      }
    }
  }

  attr_accessor :rating
  attribute :name, String, mapping: { analyzer: 'english' }
  attribute :suggest_name, String, mapping: {
    type: 'completion', payloads: true
  }
  attribute :photo, String, mapping: { index: 'no' }
  attribute :votes, Integer, mapping: { index: 'no' }
  attribute :average, Float, mapping: { index: 'no' }
  attribute :score, Float
  attribute :ingredients, Array[String], mapping: {
    analyzer: 'english',
    fields: {
      filtered: { type: 'string', analyzer: 'whitelist_ingredients' }
    }
  }
  attribute :tags, Array[String], mapping: {
    analyzer: 'english',
    fields: {
      raw: { type: 'string' }
    }
  }

  before_validation :calculate_average, if: 'rating'
  before_validation :calculate_score,   if: 'rating || score.nil?'

  validates :name, presence: true
  validates :photo, presence: true
  validates :ingredients, presence: true
  validates :votes,   numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating,  numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, unless: :new_record?
  validates :average, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0 }
  validates :score,   numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0 }

  private

  def calculate_average
    self.average = ((votes - 1) * average + rating) / votes
  end

  def calculate_score
    # Wilson lower bound with a hardcoded value for 95% confidence
    n = votes
    if n.zero?
      self.score = 0
      return
    end

    z = 1.96
    x = (average - 1) / 4
    result = (x + z * z / (2 * n) - z * Math.sqrt((x * (1 - x) + z * z / (4 * n)) / n)) / (1 + z * z / n)
    self.score = 1 + 4 * result
  end
end
