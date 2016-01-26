package com.ericsson;

import java.io.IOException;

import org.apache.zookeeper.CreateMode;
import org.apache.zookeeper.KeeperException;
import org.apache.zookeeper.WatchedEvent;
import org.apache.zookeeper.Watcher;
import org.apache.zookeeper.ZooKeeper;
import org.apache.zookeeper.data.Stat;

public class ZookeeperTest {
	public static void main(String[] argv) throws IOException, KeeperException, InterruptedException
	{
		// System.setProperty("log4j.configuration", "log4j.properties");
		
		Watcher w = new WatcherTest();
		ZooKeeper zk = new ZooKeeper("localhost:12345", 123456, w);
		Thread.sleep(500);
		zk.create("/node", new byte[] {60}, null, CreateMode.EPHEMERAL);
		Thread.sleep(500);
		zk.delete("/node", -1);
		Thread.sleep(500);
		System.out.println(zk.exists("/node", false));
		Thread.sleep(500);
		Stat stat = new Stat();
		System.out.println(new String(zk.getData("/node", false, stat)));
		Thread.sleep(500);
	}
	
	public static class WatcherTest implements Watcher
	{

		@Override
		public void process(WatchedEvent event) {
			System.out.println("Ping!!! " + event.toString());			
		}
		
	}
}
