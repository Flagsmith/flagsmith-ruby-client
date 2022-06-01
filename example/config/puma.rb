require_relative './environment'
workers 1

threads_count = 1
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        2300
environment 'development'

on_worker_boot do
  Hanami.boot
end
