import threading
import numpy as np
import tensorflow as tf
import pickle

def read_training_data(file_path):
    f = open(file_path, 'rb')
    data = pickle.load(f)
    f.close()
    return data

def get_pair(imgs):
    for uid in range(len(imgs)):
        n_img = np.arange(len(imgs[uid]))
        sur, tar = np.meshgrid(n_img, n_img)
        if uid == 0:
            pairs = np.concatenate((np.expand_dims(np.repeat(uid, len(imgs[uid])*len(imgs[uid])), axis = 1),
                                    np.expand_dims(np.reshape(sur,-1), axis = 1),
                                    np.expand_dims(np.reshape(tar,-1), axis = 1)), axis = 1)
        else:
            pairs = np.concatenate((pairs, np.concatenate((np.expand_dims(np.repeat(uid, len(imgs[uid])*len(imgs[uid])), axis = 1),
                                                           np.expand_dims(np.reshape(sur,-1), axis = 1),
                                                           np.expand_dims(np.reshape(tar,-1), axis = 1)), axis = 1)),
                                  axis = 0)
    return pairs

def load(data_dir, dirs, eye, pose):
    imgs = []
    agls = []
    ps = []
    anchor_maps = []
    for d in dirs:
        data = read_training_data(data_dir + str('/') + d + str('/') + pose + str('/') + d + str('_') + eye)        
        imgs.append(np.asarray(data['img'], dtype= np.float32)/255.0)            
        agls.append(np.concatenate([np.expand_dims(np.asarray(data['v'], dtype= np.float32), axis=1),
                                                   np.expand_dims(np.asarray(data['h'], dtype= np.float32), axis=1)],
                                    axis = 1))
        ps.append(np.asarray(data['p'], dtype= np.float32))
        anchor_maps.append(np.asarray(data['anchor_map'], dtype= np.float32))                 
    return imgs, agls, ps, anchor_maps

def load_data(data_dir, input_dirs, SIZE, eye):
    imgs, agls, _, anchor_maps = load(data_dir=data_dir, dirs = input_dirs, eye = eye, pose = '0P')
    
    if(len(imgs)!= len(agls) & len(imgs)!= len(anchor_maps)):
        sys.exit("Wrong length between 3 inputs")
        
    pairs = get_pair(agls)
    
    while True:
        idxs = np.arange(0, len(pairs))
        np.random.shuffle(idxs)
        for batch_idx in range(0, len(idxs), SIZE):
            cur_idxs = idxs[batch_idx:batch_idx+SIZE]
            pairs_batch = pairs[cur_idxs]
            img_batch = []
            fp_batch = []
            agl_batch = []
            img__batch = []
            for pair_idx in range(len(pairs_batch)):
                uID = pairs_batch[pair_idx,0]
                surID = pairs_batch[pair_idx,1]
                tarID = pairs_batch[pair_idx,2]
                img_batch.append(imgs[uID][surID])
                agl_batch.append(agls[uID][tarID] - agls[uID][surID])
                fp_batch.append(anchor_maps[uID][surID])
                img__batch.append(imgs[uID][tarID])
            
            yield np.asarray(img_batch), np.asarray(fp_batch), np.asarray(agl_batch), np.asarray(img__batch)

class DataGenerator(object):
    def __init__(self, coord, pack_size, buffer_ratio, eye, data_dir, input_dirs):
        self.queue = tf.FIFOQueue(pack_size*buffer_ratio, 
                                  ['float32','float32','float32','float32'],
                                  shapes=[(41, 51, 3),(41, 51, 14),(2,),(41, 51, 3)])
        self.threads = []
        self.coord = coord
        self.pack_size = pack_size
        self.eye = eye
        self.data_dir = data_dir
        self.input_dirs = input_dirs
        self.img = tf.placeholder(dtype=tf.float32, shape=(None,41, 51, 3))
        self.fp = tf.placeholder(dtype=tf.float32, shape=(None,41, 51, 14))
        self.agl = tf.placeholder(dtype=tf.float32, shape=(None,2))
        self.img_ = tf.placeholder(dtype=tf.float32, shape=(None,41, 51, 3))
        self.enqueue = self.queue.enqueue_many([self.img,self.fp,self.agl,self.img_])

    def size(self):
        return self.queue.size()

    def dequeue(self, num_elements):
        output = self.queue.dequeue_many(num_elements)
        return output

    def thread_main(self, sess):
        stop = False
        while not stop:
            iterator = load_data(self.data_dir, self.input_dirs, self.pack_size, self.eye)
            for img, fp, agl, img_ in iterator:
                if self.coord.should_stop():
                    stop = True
                    break
                sess.run(self.enqueue, feed_dict={self.img: img,
                                                  self.fp: fp,
                                                  self.agl: agl,
                                                  self.img_: img_})

    def start_threads(self, sess, n_threads=1):
        for _ in range(n_threads):
            thread = threading.Thread(target=self.thread_main, args=(sess, ))
            thread.daemon = True  # Thread will close when parent quits.
            thread.start()
            self.threads.append(thread)
        return self.threads