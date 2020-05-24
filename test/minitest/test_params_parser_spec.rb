# frozen_string_literal: true

require 'minitest/autorun'
require 'params_parser'

describe ParamsParser do
  # params from the spec: Array of GeoJSON Point objects or Geometry collection
  describe 'add_points' do
    describe 'with improper parameters' do
      it 'must raise ArgumentError if Points parameter absent' do
        params = {}
        _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
      end

      it 'must raise ArgumentError if Points parameter isn\'t GeoJSON Point nor Geometry collection' do
        params = 'qqq'
        _ { ParamsParser.add_points(params) }.must_raise ArgumentError
      end
    end

    describe 'with Array of GeoJSON Point objects' do
      it 'must process well-defined parameters' do
        params = {
          'Points' => [{ 'type' => 'Point', 'coordinates' => [0, 0] }]
        }

        points = ParamsParser.add_points(params)
        _(points.count).must_equal 1
      end

      it 'must raise ArgumentError if Points array is empty' do
        params = {
          'Points' => []
        }

        _ { ParamsParser.add_points(params) }.must_raise ArgumentError
      end

      it 'must raise ArgumentError if Points parameter contains not valid GeoJSON' do
        params = {
          'Points' => [{ 'type' => 'ABC', 'coordinates' => [[[0, 0], [1, 1], [0, 1], [0, 0]]] }]
        }
        _ { ParamsParser.add_points(params) }.must_raise ArgumentError
      end

      it 'must raise ArgumentError if valid GeoJSON passed to Points array but not Point' do
        params = {
          'Points' => [{ 'type' => 'Polygon', 'coordinates' => [[[0, 0], [1, 1], [0, 1], [0, 0]]] }]
        }

        _ { ParamsParser.add_points(params) }.must_raise ArgumentError
      end
    end

    describe 'with Geometry collection' do
      it 'must process well-defined Geometry collection' do
        params = {
          'Points' => {
            'type' => 'GeometryCollection', 'geometries' => [{ 'type' => 'Point', 'coordinates' => [100.0, 0.0] }]
          }
        }

        points = ParamsParser.add_points(params)
        _(points.count).must_equal 1
      end

      it 'must raise ArgumentError if Geometry collection is not valid GeoJSON' do
        params = {
          'Points' => {
            'type' => 'GeometryCollection', 'geometries' => [{ 'type' => 'abc', 'coordinates' => [100.0, 0.0] }]
          }
        }
        _ { ParamsParser.add_points(params) }.must_raise ArgumentError
      end

      it 'must raise ArgumentError if valid GeoJSON passed but not GeometryCollection' do
        params = {
          'Points' => { 'type' => 'ABC', 'geometries' => [{ 'type' => 'Point', 'coordinates' => [100.0, 0.0] }] }
        }

        _ { ParamsParser.add_points(params) }.must_raise ArgumentError
      end
    end
  end

  # params from the spec: GeoJSON Point and integer radius in feet/meters
  describe 'points_within_radius' do
    it 'must process well-defined parameters' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] },
        'Radius' => 10
      }

      radius, center_point = ParamsParser.points_within_radius(params)
      _(radius).must_equal 10
      _(center_point).must_be_kind_of RGeo::Cartesian::PointImpl
    end

    it 'must accept "Radius measure" => "meters" parameter' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] },
        'Radius' => 10,
        'Radius measure' => 'meters'
      }

      radius, = ParamsParser.points_within_radius(params)
      _(radius).must_equal 10
    end

    it 'must accept "Radius measure" => "feet" parameter' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] },
        'Radius' => 10,
        'Radius measure' => 'feet'
      }

      radius, = ParamsParser.points_within_radius(params)
      _(radius).must_equal 3.048
    end

    it 'must raise ArgumentError if Radius parameter absent' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] }
      }
      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if Radius isn\'t a number' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] },
        'Radius' => '10'
      }
      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if Radius is negative' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] },
        'Radius' => -10
      }
      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if "Radius measure" isn\'t whitelisted' do
      params = {
        'Point' => { 'type' => 'Point', 'coordinates' => [0, 0] },
        'Radius' => 10,
        'Radius measure' => 'inches'
      }
      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if Point parameter absent' do
      params = {
        'Radius' => 10
      }
      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if Point parameter is not valid GeoJSON' do
      params = {
        'Point' => { 'type' => 'ABC', 'coordinates' => [0, 0] },
        'Radius' => 10
      }
      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if valid GeoJSON passed but not Point' do
      params = {
        'Point' => { 'type' => 'Polygon', 'coordinates' => [[[0, 0], [1, 1], [0, 1], [0, 0]]] },
        'Radius' => 10
      }

      _ { ParamsParser.points_within_radius(params) }.must_raise ArgumentError
    end
  end

  # params from the spec: GeoJSON Polygon with no holes
  describe 'points_within_polygon' do
    it 'must process well-defined Polygon' do
      params = {
        'Polygon' => { 'type' => 'Polygon', 'coordinates' => [[[0, 0], [1, 1], [0, 1], [0, 0]]] }
      }

      result = ParamsParser.points_within_polygon(params)
      _(result).must_be_kind_of RGeo::Cartesian::PolygonImpl
    end

    it 'must raise ArgumentError if Polygon parameter absent' do
      params = {}
      _ { ParamsParser.points_within_polygon(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if Polygon parameter is not valid GeoJSON' do
      params = {
        'Polygon' => { 'type' => 'ABC', 'coordinates' => [[[0, 0], [1, 1], [0, 1], [0, 0]]] }
      }
      _ { ParamsParser.points_within_polygon(params) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if valid GeoJSON passed but not Polygon' do
      params = {
        'Polygon' => { 'type' => 'Point', 'coordinates' => [0, 0] }
      }

      _ { ParamsParser.points_within_polygon(params) }.must_raise ArgumentError
    end

    # quick check to be sure that RGeo raises errors on well-formatted logically improper data
    it 'must raise RGeo::Error::RGeoError if Polygon contains one point' do
      params = {
        'Polygon' => { 'type' => 'Polygon', 'coordinates' => [[[0, 0]]] }
      }

      _ { ParamsParser.points_within_polygon(params) }.must_raise RGeo::Error::RGeoError
    end
  end

  describe 'parse_body' do
    it 'must raise ArgumentError if body is empty' do
      _ { ParamsParser.parse_body(nil) }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if body is an empty string' do
      _ { ParamsParser.parse_body(' ') }.must_raise ArgumentError
    end

    it 'must raise ArgumentError if body is n\'t JSON' do
      _ { ParamsParser.parse_body('{{{') }.must_raise ArgumentError
    end
  end
end
