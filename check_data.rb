#!/usr/bin/env ruby

require_relative 'CheckModuleData'

a = CheckModuleData.new('yaml', 'hiera.yaml', 'sudo')

a.match_all
